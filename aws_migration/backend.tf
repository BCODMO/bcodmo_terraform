resource "aws_s3_bucket" "bcodmo_terraform_state" {
  bucket = "bcodmo-central-terraform-state-${terraform.workspace}"

  # Enable versioning so we can see the full revision history of our
  # state files
  versioning {
    enabled = true
  }

  # Enable server-side encryption by default
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tstate" {
  bucket = aws_s3_bucket.bcodmo_terraform_state.id

  block_public_acls   = true
  block_public_policy = true
  restrict_public_buckets = true
  ignore_public_acls = true
}

resource "aws_dynamodb_table" "bcodmo_terraform_locks" {
  name         = "bcodmo-terraform-locks-${terraform.workspace}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

terraform {
  backend "s3" {}
}