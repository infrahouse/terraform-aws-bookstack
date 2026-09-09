locals {
  module_version = "4.3.0"

  tags = {
    created_by_module : "infrahouse/bookstack/aws"
  }
  smtp_endpoints = {
    us-west-1 : "email-smtp.us-west-1.amazonaws.com"
    us-west-2 : "email-smtp.us-west-2.amazonaws.com"
    us-east-1 : "email-smtp.us-east-1.amazonaws.com"
    us-east-2 : "email-smtp.us-east-2.amazonaws.com"
  }
  dns_a_records        = var.dns_a_records == null ? [var.service_name] : var.dns_a_records
  ec2_role_name        = "${var.service_name}-${random_string.role-suffix.result}"
  ec2_role_arn         = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.ec2_role_name}"
  ami_name_pattern_pro = "ubuntu-pro-server/images/hvm-ssd-gp3/ubuntu-${var.ubuntu_codename}-*"

  # EC2 caps user data at 16384 bytes of *decoded* payload. The cloud-init module
  # emits an already-base64-encoded string (its data.cloudinit_config sets
  # base64_encode = true), which is ~4/3 longer and is not what AWS measures.
  #
  # base64decode() cannot recover the payload length: the payload is gzip binary
  # when var.compress_userdata is set, and length() counts characters rather than
  # bytes, so it undercounts multi-byte UTF-8. Derive the byte count from the
  # encoding instead -- every 4 base64 chars carry 3 bytes, less the padding.
  # Base64 is ASCII, so length() on the encoded string is an exact byte count.
  #
  # nonsensitive() is required, not cosmetic: the cloud-init module marks its
  # userdata output sensitive, so every derived value inherits the mark and a
  # root module re-exporting userdata_size_info fails to plan. Only the byte
  # count is unwrapped here -- the payload itself is never surfaced.
  userdata_b64       = module.bookstack-userdata.userdata
  userdata_b64_chars = nonsensitive(length(local.userdata_b64))
  userdata_bytes = nonsensitive(floor(length(local.userdata_b64) / 4) * 3 - (
    endswith(local.userdata_b64, "==") ? 2 : endswith(local.userdata_b64, "=") ? 1 : 0
  ))
  userdata_limit = 16384
}
