import json
from os import path as osp, remove
from shutil import rmtree
from textwrap import dedent
from time import sleep

import pytest
from infrahouse_core.aws.asg import ASG
from infrahouse_core.timeout import timeout
from pytest_infrahouse import terraform_apply
from pytest_infrahouse.utils import wait_for_instance_refresh

from tests.conftest import (
    LOG,
    TERRAFORM_ROOT_DIR,
)


@pytest.mark.parametrize("aws_provider_version", ["~> 6.0"], ids=["aws-6"])
def test_module(
    service_network,
    ses,
    aws_region,
    test_role_arn,
    test_zone_name,
    keep_after,
    aws_provider_version,
    boto3_session,
):
    subnet_public_ids = service_network["subnet_public_ids"]["value"]
    # subnet_private_ids = service_network["subnet_private_ids"]["value"]
    internet_gateway_id = service_network["internet_gateway_id"]["value"]

    ubuntu_codename = "noble"

    terraform_module_dir = osp.join(TERRAFORM_ROOT_DIR, "bookstack")

    # Clean up state files to ensure fresh terraform init
    state_files = [
        osp.join(terraform_module_dir, ".terraform"),
        osp.join(terraform_module_dir, ".terraform.lock.hcl"),
    ]
    for state_file in state_files:
        try:
            if osp.isdir(state_file):
                rmtree(state_file)
            elif osp.isfile(state_file):
                remove(state_file)
        except FileNotFoundError:
            pass

    # Generate terraform.tf with specified AWS provider version
    with open(osp.join(terraform_module_dir, "terraform.tf"), "w") as fp:
        fp.write(
            dedent(
                f"""
                terraform {{
                  required_version = "~> 1.5"
                  required_providers {{
                    aws = {{
                      source = "hashicorp/aws"
                      version = "{aws_provider_version}"
                    }}
                  }}
                }}
                """
            )
        )

    # ALB access logs are replicated cross-region; pick a region different from
    # the deployment region so the replica bucket isn't in the same region.
    replication_region = "us-east-2" if aws_region == "us-east-1" else "us-east-1"
    with open(osp.join(terraform_module_dir, "terraform.tfvars"), "w") as fp:
        fp.write(
            dedent(
                f"""
                    region = "{aws_region}"
                    test_zone = "{test_zone_name}"

                    lb_subnet_ids       = {json.dumps(subnet_public_ids)}
                    backend_subnet_ids  = {json.dumps(subnet_public_ids)}
                    internet_gateway_id = "{internet_gateway_id}"
                    ubuntu_codename     = "{ubuntu_codename}"
                    replication_region  = "{replication_region}"
                    """
            )
        )
        if test_role_arn:
            fp.write(
                dedent(
                    f"""
                        role_arn        = "{test_role_arn}"
                        """
                )
            )
    with terraform_apply(
        terraform_module_dir,
        destroy_after=not keep_after,
        json_output=True,
    ) as tf_output:
        LOG.debug("Terraform output:\n%s", json.dumps(tf_output, indent=4))

        # Test database connectivity from BookStack instances
        asg_name = tf_output["autoscaling_group_name"]["value"]
        db_address = tf_output["database_address"]["value"]
        db_name = tf_output["database_name"]["value"]
        db_secret_name = tf_output["database_secret_name"]["value"]

        LOG.info("Testing database connectivity from ASG: %s", asg_name)

        # Get ASG and instances
        asg = ASG(asg_name, region=aws_region, role_arn=test_role_arn)

        # Wait for any instance refreshes to complete
        autoscaling_client = boto3_session.client("autoscaling", region_name=aws_region)
        wait_for_instance_refresh(asg_name, autoscaling_client)

        instances = list(asg.instances)

        assert len(instances) > 0, "No instances found in ASG"

        # Use the first instance to test database connectivity
        instance = instances[0]
        LOG.info("Testing from instance: %s", instance.instance_id)

        # Wait for puppet to complete (retry for up to 15 minutes)
        LOG.info(
            "Waiting for puppet to complete on instance %s...", instance.instance_id
        )
        cerr = None
        try:
            with timeout(15 * 60):
                while True:
                    response_code, _, cerr = instance.execute_command(
                        "ls /var/run/puppet-done"
                    )
                    if response_code == 0:
                        LOG.info("Puppet completed successfully")
                        break
                    LOG.info("Puppet not yet complete, retrying...")
                    sleep(30)
        except TimeoutError:
            pytest.fail(
                f"Puppet did not complete within 15 minutes. Last check result: {cerr}"
            )

        # Execute the database connectivity test script
        # The script is deployed via cloud-init extra_files to /usr/local/bin/test-db-connectivity.sh
        # It reads database configuration from puppet facter and tests MySQL connection
        LOG.info("Executing database connectivity test script on instance...")
        response_code, cout, cerr = instance.execute_command(
            "/usr/local/bin/test-db-connectivity.sh"
        )

        LOG.info("Database connectivity test result:")
        LOG.info("Exit code: %s", response_code)
        LOG.info("Output: %s", cout)
        LOG.info("Stderr: %s", cerr)

        # Assert the test passed
        assert response_code == 0, (
            f"Database connectivity test failed with exit code {response_code}\n"
            f"Output: {cout}\n"
            f"Error: {cerr}"
        )
        assert (
            "Database connectivity test PASSED" in cout
        ), "Database connectivity test did not complete successfully"

        LOG.info("Database connectivity validated successfully")

        # Validate userdata size to catch AWS 16KB limit issues
        userdata_info = tf_output.get("userdata_size_info", {}).get("value", {})
        LOG.info("Userdata size validation:")
        LOG.info("  Compression enabled: %s", userdata_info.get("compression_enabled"))
        LOG.info("  Base64 size: %s KB", userdata_info.get("base64_kb"))
        LOG.info("  AWS limit: %s KB", userdata_info.get("aws_limit_kb"))
        LOG.info("  Utilization: %s", userdata_info.get("utilization_pct"))
        LOG.info("  Status: %s", userdata_info.get("status"))
        LOG.info("  Recommendation: %s", userdata_info.get("recommendation"))

        # Assert userdata is within AWS limits
        base64_bytes = userdata_info.get("base64_bytes", 0)
        assert base64_bytes <= 16384, (
            f"Userdata exceeds AWS 16KB limit: {userdata_info.get('base64_kb')} KB. "
            f"Status: {userdata_info.get('status')}. "
            f"{userdata_info.get('recommendation')}"
        )

        # Warn if approaching limit (14KB = 87.5% of 16KB)
        if base64_bytes > 14336:
            LOG.warning(
                "⚠️  Userdata is approaching AWS limit (%s KB / 16 KB). "
                "Consider enabling compression (compress_userdata = true) or optimizing before adding more content.",
                userdata_info.get("base64_kb"),
            )
