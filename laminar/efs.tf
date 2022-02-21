resource "aws_efs_file_system" "efs_volume" {
  creation_token = "laminar-${var.environment[terraform.workspace]}"
  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }

  tags = {
    Name = "laminar-${var.environment[terraform.workspace]}-efs"
  }

}

resource "aws_efs_mount_target" "laminar_cache" {
  file_system_id  = aws_efs_file_system.efs_volume.id
  subnet_id       = aws_subnet.subnet_public_a.id
  security_groups = [aws_security_group.laminar_hidden.id]
}
