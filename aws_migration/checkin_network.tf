resource "aws_vpc" "bcodmo_checkin_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true

  tags = {
    Name = "bcodmo-checkin-vpc-${terraform.workspace}"
  }
}

resource "aws_internet_gateway" "checkin_igw" {
  vpc_id = aws_vpc.bcodmo_checkin_vpc.id

  tags = {
    Name = "bcodmo-checkin-igw-${terraform.workspace}"
  }
}


resource "aws_subnet" "bcodmo_checkin_us_east_1a" {
  vpc_id     = aws_vpc.bcodmo_checkin_vpc.id
  availability_zone = "us-east-1a"
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "bcodmo-checkin-us-east-1a-${terraform.workspace}"
  }
}

resource "aws_subnet" "bcodmo_checkin_us_east_1b" {
  vpc_id     = aws_vpc.bcodmo_checkin_vpc.id
  availability_zone = "us-east-1b"
  cidr_block = "10.0.2.0/28"

  tags = {
    Name = "bcodmo-checkin-us-east-1b-${terraform.workspace}"
  }
}

resource "aws_subnet" "bcodmo_checkin_public_us_east_1a" {
  vpc_id     = aws_vpc.bcodmo_checkin_vpc.id
  availability_zone = "us-east-1a"
  cidr_block = "10.0.4.0/24"

  tags = {
    Name = "bcodmo-checkin-public-us-east-1a-${terraform.workspace}"
  }
}

resource "aws_security_group" "bcodmo_checkin_ecs_sg" {
  name        = "bcodmo-checkin-ecs-${terraform.workspace}"
  description = "Created by Terraform"
  vpc_id      = aws_vpc.bcodmo_checkin_vpc.id


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

resource "aws_security_group" "bcodmo_checkin_efs_sg" {
  name        = "bcodmo-checkin-efs-${terraform.workspace}"
  description = "Created by Terraform"
  vpc_id      = aws_vpc.bcodmo_checkin_vpc.id


  ingress {
        description = "Ingress from ECS"
        from_port   = 2049
        to_port     = 2049
        protocol    = "tcp"
        security_groups = [
        aws_security_group.bcodmo_checkin_ecs_sg.id,
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

resource "aws_network_interface" "test" {
  subnet_id       = aws_subnet.bcodmo_checkin_public_us_east_1a.id
  security_groups = [aws_security_group.bcodmo_checkin_ecs_sg.id]
  tags = {
    Name = "bcodmo-checkin-interface-${terraform.workspace}"
  }

}

resource "aws_eip" "checkin_eip" {
  vpc = true
  depends_on                = [aws_internet_gateway.checkin_igw]
}

resource "aws_nat_gateway" "checkin_nat_gw" {
  allocation_id = aws_eip.checkin_eip.id
  subnet_id     = aws_subnet.bcodmo_checkin_public_us_east_1a.id

  tags = {
    Name = "bcodmo-checkin-NAT-${terraform.workspace}"
  }
  depends_on = [aws_internet_gateway.checkin_igw]
}

resource "aws_route_table" "checkin_public_rt" {
  vpc_id = "${aws_vpc.bcodmo_checkin_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.checkin_igw.id}"
  }
  tags = {
    Name = "bcodmo-checkin-public-rt-${terraform.workspace}"
  }
}

resource "aws_route_table_association" "checkin_public_rta" {
  subnet_id      = aws_subnet.bcodmo_checkin_public_us_east_1a.id
  route_table_id = aws_route_table.checkin_public_rt.id
}

resource "aws_route_table" "checkin_private_rt" {
  vpc_id = "${aws_vpc.bcodmo_checkin_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.checkin_nat_gw.id}"
  }
  tags = {
    Name = "bcodmo-checkin-private-rt-${terraform.workspace}"
  }
}

resource "aws_route_table_association" "checkin_private_rta_1a" {
  subnet_id      = aws_subnet.bcodmo_checkin_us_east_1a.id
  route_table_id = aws_route_table.checkin_private_rt.id
}
resource "aws_route_table_association" "checkin_private_rta_1b" {
  subnet_id      = aws_subnet.bcodmo_checkin_us_east_1b.id
  route_table_id = aws_route_table.checkin_private_rt.id
}