
resource "aws_s3_bucket" "results" {
  bucket = "laminar-results"
  acl    = "private"
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }

  lifecycle_rule {
    id      = "expire_objects"
    enabled = true

    prefix = "*"

    expiration {
      days = 20
    }
  }
}

resource "aws_s3_bucket" "load" {
  bucket = "laminar-load"
  acl    = "private"
}

resource "aws_s3_bucket" "history" {
  bucket = "laminar-history"
  acl    = "private"
}

resource "aws_s3_bucket" "dump" {
  bucket = "laminar-dump"
  acl    = "private"
}
