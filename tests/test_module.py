import json
from os import path as osp, remove
from shutil import rmtree
from textwrap import dedent
from time import sleep

import pytest
from infrahouse_core.aws.asg import ASG
from pytest_infrahouse import terraform_apply

from tests.conftest import (
    LOG,
    TERRAFORM_ROOT_DIR,
)


@pytest.mark.parametrize(
    "aws_provider_version", ["~> 5.62", "~> 6.0"], ids=["aws-5", "aws-6"]
)
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
        LOG.info("%s", json.dumps(tf_output, indent=4))

        # Test database connectivity from BookStack instances
        asg_name = tf_output["autoscaling_group_name"]["value"]
        db_address = tf_output["database_address"]["value"]
        db_name = tf_output["database_name"]["value"]
        db_secret_name = tf_output["database_secret_name"]["value"]

        LOG.info("Testing database connectivity from ASG: %s", asg_name)

        # Get ASG and instances
        asg = ASG(asg_name, region=aws_region, role_arn=test_role_arn)

        # Wait for any instance refreshes to complete
        LOG.info("Checking for instance refreshes in ASG: %s", asg_name)
        max_refresh_wait = 20 * 60  # 20 minutes
        refresh_check_interval = 30  # Check every 30 seconds
        refresh_elapsed = 0

        while refresh_elapsed < max_refresh_wait:
            refreshes = asg.instance_refreshes
            # Filter for in-progress refreshes
            in_progress = [
                r for r in refreshes if r.get("Status") in ["Pending", "InProgress"]
            ]

            if not in_progress:
                LOG.info("No in-progress instance refreshes found")
                break

            LOG.info(
                "Instance refresh in progress (waited %d/%d seconds): %s",
                refresh_elapsed,
                max_refresh_wait,
                [r.get("InstanceRefreshId") for r in in_progress],
            )
            sleep(refresh_check_interval)
            refresh_elapsed += refresh_check_interval

        if refresh_elapsed >= max_refresh_wait:
            LOG.warning("Instance refresh timeout reached, proceeding anyway")

        instances = list(asg.instances)

        assert len(instances) > 0, "No instances found in ASG"

        # Use the first instance to test database connectivity
        instance = instances[0]
        LOG.info("Testing from instance: %s", instance.instance_id)

        # Wait for puppet to complete (retry for up to 15 minutes)
        LOG.info(
            "Waiting for puppet to complete on instance %s...", instance.instance_id
        )
        max_wait_time = 15 * 60  # 15 minutes in seconds
        retry_interval = 30  # Check every 30 seconds
        elapsed_time = 0
        puppet_done = False

        while elapsed_time < max_wait_time:
            response_code, _, cerr = instance.execute_command("ls /tmp/puppet-done")
            if response_code == 0:
                puppet_done = True
                LOG.info("Puppet completed successfully after %d seconds", elapsed_time)
                break
            else:
                LOG.info(
                    "Puppet not yet complete (waited %d/%d seconds), retrying...",
                    elapsed_time,
                    max_wait_time,
                )
                sleep(retry_interval)
                elapsed_time += retry_interval

        assert puppet_done, (
            f"Puppet did not complete within {max_wait_time} seconds. "
            f"Last check result: {cerr}"
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
