resource "aws_security_group" "db" {
  description = "${var.service_name} RDS instance"
  name_prefix = var.service_name
  vpc_id      = data.aws_vpc.selected.id
  tags = merge(
    {
      Name : "${var.service_name} RDS"
    },
    local.tags
  )
}

resource "aws_vpc_security_group_ingress_rule" "mysql" {
  description       = "Allow mysql traffic"
  security_group_id = aws_security_group.db.id
  from_port         = 3306
  to_port           = 3306
  ip_protocol       = "tcp"
  cidr_ipv4         = data.aws_vpc.selected.cidr_block
  tags = merge(
    {
      Name = "mysql access"
    },
    local.tags
  )
}
