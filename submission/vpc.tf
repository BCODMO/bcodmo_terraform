resource "aws_default_vpc" "default" {}

resource "aws_default_subnet" "default_1a" {
  availability_zone = "us-east-1a"
}

resource "aws_default_subnet" "default_1b" {
  availability_zone = "us-east-1b"
}

resource "aws_security_group" "submission" {
  name        = "submission-ecs-${var.environment[terraform.workspace]}"
  description = "Created by Terraform"
  vpc_id      = aws_default_vpc.default.id

}

resource "aws_security_group_rule" "allow_submission" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = "true"
  security_group_id = aws_security_group.submission.id
  description       = "All ingress for self"

}

resource "aws_security_group_rule" "all_https" {
  type              = "ingress"
  description       = "Access HTTPS from the world"
  from_port         = 443
  to_port           = 443
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.submission.id

}

resource "aws_security_group_rule" "all_http" {
  type              = "ingress"
  description       = "Access HTTP from the world (for redirect)"
  from_port         = 80
  to_port           = 80
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.submission.id

}

resource "aws_security_group_rule" "submission_out" {
  type              = "egress"
  description       = ""
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.submission.id

}
