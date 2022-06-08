resource "aws_secretsmanager_secret" "checkin_api_key" {
  name = "CHECKIN_API_KEY_${var.environment[terraform.workspace]}"
}

resource "aws_secretsmanager_secret" "redmine_api_access_key" {
  name = "REDMINE_API_ACCESS_KEY_${var.environment[terraform.workspace]}"
}

resource "aws_secretsmanager_secret" "id_generator_api_key" {
  name = "ID_GENERATOR_API_KEY_${var.environment[terraform.workspace]}"
}
