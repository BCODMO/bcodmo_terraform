resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "laminar-${var.environment[terraform.workspace]}-vpc"
  }
}


resource "aws_subnet" "subnet_public_a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "laminar-${var.environment[terraform.workspace]}-subnet-public-a"
  }
}

resource "aws_subnet" "subnet_public_b" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "laminar-${var.environment[terraform.workspace]}-subnet-public-b"
  }
}

resource "aws_security_group" "laminar" {
  name        = "laminar-ecs-${var.environment[terraform.workspace]}"
  description = "Created by Terraform"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Access all from WHOI"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.whoi_ip]
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
    ignore_changes = [ingress]
  }
}


resource "aws_security_group" "laminar_hidden" {
  name        = "laminar-ecs-hidden-${var.environment[terraform.workspace]}"
  description = "Created by Terraform"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "All ingress for self and other laminar security group"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = "true"
    security_groups = [
      aws_security_group.laminar.id,
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle {
    ignore_changes = [ingress]
  }
}

resource "aws_security_group_rule" "allow_laminar_hidden" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.laminar_hidden.id
  security_group_id        = aws_security_group.laminar.id
  description              = "All ingress for hidden security group"

}


resource "aws_subnet" "subnet_private" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.8.0/21"
  map_public_ip_on_launch = false
  tags = {
    Name = "laminar-${var.environment[terraform.workspace]}-subnet-private"
  }
}

// Should be imported
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
}


resource "aws_route_table" "route_table_public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    Name = "laminar-${var.environment[terraform.workspace]}-route-table-public"
  }
}

resource "aws_route_table_association" "route_table_association_public_a" {
  subnet_id      = aws_subnet.subnet_public_a.id
  route_table_id = aws_route_table.route_table_public.id
}
resource "aws_route_table_association" "route_table_association_public_b" {
  subnet_id      = aws_subnet.subnet_public_b.id
  route_table_id = aws_route_table.route_table_public.id
}


resource "aws_eip" "eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.internet_gateway]
  tags = {
    Name = "laminar-${var.environment[terraform.workspace]}-eip"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.subnet_public_a.id

  tags = {
    Name = "laminar-${var.environment[terraform.workspace]}-nat-gateway"
  }
}

resource "aws_route_table" "route_table_private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "laminar-${var.environment[terraform.workspace]}-route-table-private"
  }
}


resource "aws_route_table_association" "route_table_association_private" {
  subnet_id      = aws_subnet.subnet_private.id
  route_table_id = aws_route_table.route_table_private.id
}
