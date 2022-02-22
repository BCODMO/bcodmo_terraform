variable "region" {
  default = "us-east-1"
}

variable "laminar_tmp_directory" {
  default = "/laminar"
}

variable "github_issue_access_token" {}

variable "whoi_ip" {
  default = "128.128.0.0/16"
}

variable "environment" {
  default = {
    "default" : "staging"
    "prod" : "prod"
  }
}


variable "laminar_version" {}
variable "laminar_versions" {}
variable "laminar_documentation_url" {}
variable "laminar_orcid_auth_client_id" {}
variable "laminar_orcid_auth_url" {}
variable "laminar_orcid_jwks_endpoint" {}
variable "laminar_orcid_api_url" {}
variable "laminar_submission_s3_bucket" {}
variable "laminar_redmine_issue_base_url" {}
variable "laminar_submission_base_url" {}
variable "laminar_api_url" {}
variable "laminar_file_staging_redis_url" {}
