resource "aws_instance" "instance" {
  ami                         = var.instance_ami
  availability_zone           = "us-east-1a"
  instance_type               = "t3.micro"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sm_ui.id]
  key_name = "sm_ui"
  subnet_id                   = aws_default_subnet.default_1a.id
     tags = {
        Name = "SM_UI"
      }
 
}

