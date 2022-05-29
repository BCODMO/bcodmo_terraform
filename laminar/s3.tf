resource "aws_s3_bucket" "results" {
  bucket = "laminar-results"
}

resource "aws_s3_bucket_acl" "results" {
  bucket = aws_s3_bucket.results.id
  acl    = "private"
}

resource "aws_s3_bucket_cors_configuration" "results" {
  bucket = aws_s3_bucket.results.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }

}

resource "aws_s3_bucket_public_access_block" "results" {
  bucket = aws_s3_bucket.results.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket_lifecycle_configuration" "results" {
  bucket = aws_s3_bucket.results.id
  rule {
    id      = "expire_objects"
    filter {}
    expiration {
      days = 20
    }
    status = "Enabled"
  }
}



resource "aws_s3_bucket" "load" {
  bucket = "laminar-load"
}
resource "aws_s3_bucket_acl" "load" {
  bucket = aws_s3_bucket.load.id
  acl    = "private"
}
resource "aws_s3_bucket_public_access_block" "load" {
  bucket = aws_s3_bucket.load.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket" "history" {
  bucket = "laminar-history"
}

resource "aws_s3_bucket_acl" "history" {
  bucket = aws_s3_bucket.history.id
  acl    = "private"
}
resource "aws_s3_bucket_public_access_block" "history" {
  bucket = aws_s3_bucket.history.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket" "dump" {
  bucket = "laminar-dump"
}
resource "aws_s3_bucket_acl" "dump" {
  bucket = aws_s3_bucket.dump.id
  acl    = "private"
}
resource "aws_s3_bucket_public_access_block" "dump" {
  bucket = aws_s3_bucket.dump.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}
resource "aws_s3_bucket_cors_configuration" "dump" {
  bucket = aws_s3_bucket.dump.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }

}
