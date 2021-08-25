resource "aws_default_vpc" "default" {}

resource "aws_default_subnet" "default_1a" {
  availability_zone = "us-east-1a"
}

resource "aws_default_subnet" "default_1b" {
  availability_zone = "us-east-1b"
}


resource "aws_security_group" "submission" {
  name        = "submission-ecs-${terraform.workspace}"
  description = "Created by Terraform"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    description = "Access all from WHOI"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "All ingress for self"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = "true"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle {
    #ignore_changes = [ingress]
  }
}


