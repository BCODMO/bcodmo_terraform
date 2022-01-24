resource "aws_efs_file_system" "efs_volume" {
  creation_token = "laminar-${terraform.workspace}"
  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }

}

resource "aws_efs_mount_target" "laminar_cache1b" {
  file_system_id  = aws_efs_file_system.efs_volume.id
  subnet_id       = aws_default_subnet.default_1b.id
  security_groups = [aws_security_group.laminar_hidden.id]
}
resource "aws_efs_mount_target" "laminar_cache1a" {
  file_system_id  = aws_efs_file_system.efs_volume.id
  subnet_id       = aws_default_subnet.default_1a.id
  security_groups = [aws_security_group.laminar_hidden.id]
}
