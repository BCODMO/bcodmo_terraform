resource "aws_s3_bucket" "projects" {
  bucket = var.environment[terraform.workspace] == "staging" ? "bcodmo-projects-staging" : "bcodmo-projects"
}

resource "aws_s3_bucket_acl" "projects" {
  bucket = aws_s3_bucket.projects.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "projects" {
  bucket = aws_s3_bucket.projects.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_cors_configuration" "projects" {
  bucket = aws_s3_bucket.projects.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }

}

resource "aws_s3_bucket_public_access_block" "projects" {
  bucket = aws_s3_bucket.projects.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}


resource "aws_s3_bucket" "submissions" {
  bucket = var.environment[terraform.workspace] == "staging" ? "bcodmo-submissions-staging" : "bcodmo-submissions"
}

resource "aws_s3_bucket_acl" "submissions" {
  bucket = aws_s3_bucket.submissions.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "submissions" {
  bucket = aws_s3_bucket.submissions.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_cors_configuration" "submissions" {
  bucket = aws_s3_bucket.submissions.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_public_access_block" "submissions" {
  bucket = aws_s3_bucket.submissions.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}


resource "aws_s3_bucket" "submissions_permissions" {
  bucket = var.environment[terraform.workspace] == "staging" ? "bcodmo-submissions-permissions-staging" : "bcodmo-submissions-permissions"
}

resource "aws_s3_bucket_acl" "submissions_permissions" {
  bucket = aws_s3_bucket.submissions_permissions.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "submissions_permissions" {
  bucket = aws_s3_bucket.submissions_permissions.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}
