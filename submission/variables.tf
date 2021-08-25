variable "region" {
  default = "us-east-1"
}

variable "aws_endpoint" {
  default = "s3.amazonaws.com"
}
variable "aws_access_key" {}
variable "aws_secret_access_key" {}

variable "api_request_key" {}
variable "api_response_key" {}

variable "whoi_ip" {
  default = "128.128.0.0/16"
}

variable "id_generator_url" {}
variable "id_generator_api_key" {}

variable "auth_url" {
  default = "https://orcid.org/oauth/authorize"
}
variable "auth_force_logout_url" {
  default = "https://orcid.org/userStatus.json?logUserOut=true"
}
variable "auth_token_url" {
  default = "https://orcid.org/oauth/token"
}
variable "auth_client_id" {}
variable "auth_client_secret" {}

variable "orcid_api_url" {
  default = "https://pub.orcid.org/v3.0"
}


variable "submission_version" {}

variable "lod_dataset_roles_uri" {}
variable "lod_project_roles_uri" {}
variable "lod_programs_uri" {}

variable "orcid_safelist" {}

variable "redmine_api_url" {}
variable "redmine_api_access_key" {}
variable "redmine_project_id" {}
variable "redmine_category_id_project" {}
variable "redmine_category_id_dataset" {}
variable "redmine_custom_field_id_submission_tool_id" {}
variable "redmine_custom_field_id_submission_state" {}
variable "redmine_status_id" {}
variable "redmine_tracker_id" {}

variable "submission_github_issue_uri" {}


variable "email_from" {}
variable "email_password" {}
variable "email_host" {}
variable "email_port" {}
variable "email_to" {}
