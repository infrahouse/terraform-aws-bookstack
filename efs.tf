data "aws_kms_key" "efs_default" {
  count  = var.efs_encrypted && var.efs_kms_key_id == null ? 1 : 0
  key_id = "alias/aws/elasticfilesystem"
}

resource "aws_efs_file_system" "bookstack-uploads" {
  creation_token = "bookstack-uploads"
  encrypted      = var.efs_encrypted
  kms_key_id     = var.efs_encrypted ? (var.efs_kms_key_id != null ? var.efs_kms_key_id : data.aws_kms_key.efs_default[0].arn) : null
  tags = merge(
    {
      Name = "bookstack-uploads"
    },
    local.tags
  )
}

resource "aws_efs_mount_target" "bookstack-uploads" {
  for_each       = toset(var.backend_subnet_ids)
  file_system_id = aws_efs_file_system.bookstack-uploads.id
  subnet_id      = each.key
  security_groups = [
    aws_security_group.efs.id
  ]
  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_security_group" "efs" {
  description = "Security group for EFS volume"
  name_prefix = "bookstack-efs-"
  vpc_id      = data.aws_subnet.selected.vpc_id

  tags = merge(
    {
      Name : "Bookstack uploads"
    },
    local.tags
  )
}

resource "aws_vpc_security_group_ingress_rule" "efs" {
  description       = "Allow NFS traffic to EFS volume"
  security_group_id = aws_security_group.efs.id
  from_port         = 2049
  to_port           = 2049
  ip_protocol       = "tcp"
  cidr_ipv4         = data.aws_vpc.selected.cidr_block
  tags = merge({
    Name = "NFS traffic"
    },
    local.tags
  )
}

resource "aws_vpc_security_group_ingress_rule" "efs_icmp" {
  description       = "Allow all ICMP traffic"
  security_group_id = aws_security_group.efs.id
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
  cidr_ipv4         = "0.0.0.0/0"
  tags = merge({
    Name = "ICMP traffic"
    },
    local.tags
  )
}

resource "aws_vpc_security_group_egress_rule" "efs" {
  security_group_id = aws_security_group.efs.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  tags = merge({
    Name = "EFS outgoing traffic"
    },
    local.tags
  )
}
