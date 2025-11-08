import json
from os import path as osp, remove
from shutil import rmtree
from textwrap import dedent

import pytest
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
