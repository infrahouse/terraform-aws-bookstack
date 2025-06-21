import json
from os import path as osp
from textwrap import dedent

from pytest_infrahouse import terraform_apply

from tests.conftest import (
    LOG,
    TERRAFORM_ROOT_DIR,
)


def test_module(
    service_network, aws_region, test_role_arn, test_zone_name, keep_after
):
    subnet_public_ids = service_network["subnet_public_ids"]["value"]
    # subnet_private_ids = service_network["subnet_private_ids"]["value"]
    internet_gateway_id = service_network["internet_gateway_id"]["value"]

    ubuntu_codename = "noble"

    terraform_module_dir = osp.join(TERRAFORM_ROOT_DIR, "bookstack")
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
