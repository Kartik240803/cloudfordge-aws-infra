locals {
  https_enabled = var.certificate_arn != "" || var.domain_name != ""
}

resource "aws_security_group" "alb" {
  name        = "${local.prefix}-sg-alb"
  description = "Public load balancer"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.prefix}-sg-alb" }
}

resource "aws_security_group" "app" {
  name        = "${local.prefix}-sg-app"
  description = "ECS tasks"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.prefix}-sg-app" }
}

resource "aws_security_group" "rds" {
  name        = "${local.prefix}-sg-rds"
  description = "RDS MySQL"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.prefix}-sg-rds" }
}

resource "aws_security_group" "efs" {
  name        = "${local.prefix}-sg-efs"
  description = "EFS mount targets"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.prefix}-sg-efs" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count             = local.https_enabled ? 1 : 0
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.alb.id
}

# Tasks need outbound access to RDS, EFS, ECR, Secrets Manager, SMTP and OAuth providers.
resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_app" {
  security_group_id            = aws_security_group.rds.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "efs_from_app" {
  security_group_id            = aws_security_group.efs.id
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  referenced_security_group_id = aws_security_group.app.id
}
