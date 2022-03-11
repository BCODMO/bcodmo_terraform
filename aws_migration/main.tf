provider "aws" {
  region = var.region
}

resource "aws_dynamodb_table" "bcodmo_jobs" {
  name         = "bcodmo-jobs-${terraform.workspace}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "JobID"

  attribute {
    name = "JobID"
    type = "S"
  }
}

resource "aws_s3_bucket" "pdf" {
  bucket = "pdf-generator-${terraform.workspace}"
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

    expiration {
      days = 1
    }
  }
}

resource "aws_s3_bucket_policy" "pdf_generator" {
  bucket = aws_s3_bucket.pdf.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression's result to valid JSON syntax.
  policy = jsonencode({
    Version : "2012-10-17",
    Id      : "MYBUCKETPOLICY",
    Statement : [
      {
        Sid       : "LambdaAllow",
        Effect    : "Allow",
        Principal : {
          "AWS": [
            "${aws_iam_role.iam_for_lambda_pdf_gen.arn}"
          ]
        },
        Action    : [
          "s3:PutObject",
          "s3:GetObject"
          ],
        Resource : [
          "${aws_s3_bucket.pdf.arn}",
          "${aws_s3_bucket.pdf.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_s3_bucket_public_access_block" "pdf" {
  bucket = aws_s3_bucket.pdf.id

  block_public_acls   = true
  block_public_policy = true
  restrict_public_buckets = true
  ignore_public_acls = true
}

# check-in

resource "aws_kms_key" "bcodmo_checkin_s3_kms" {
  description             = "KMS key for the bco-dmo file S3 bucket"
  deletion_window_in_days = 15
  tags = {
    Name = "bcodmo-checkin-${terraform.workspace}"
  }
}

resource "aws_s3_bucket" "bcodmo_checkin_s3" {
  bucket = "bcodmo-files-${terraform.workspace}"
  acl    = "private"
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_public_access_block" "bcodmo_checkin" {
  bucket = aws_s3_bucket.bcodmo_checkin_s3.id

  block_public_acls   = true
  block_public_policy = true
  restrict_public_buckets = true
  ignore_public_acls = true
}

resource "aws_sqs_queue" "bcodmo_checkin_dlq" {
  name                      = "bcodmo-checkin-dlq-${terraform.workspace}"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 1209600
  
}

resource "aws_sqs_queue" "bcodmo_checkin_queue" {
  name                      = "bcodmo-checkin-${terraform.workspace}"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 345600
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.bcodmo_checkin_dlq.arn
    maxReceiveCount     = 3
  })
  # redrive_allow_policy = jsonencode({
  #   # There's a terraform incompatibility with aws on. Hence allowAll. Open gitIssue
  #   redrivePermission = "allowAll"
  # })
  
}

resource "aws_sqs_queue_policy" "bcodmo_checkin_queue_policy" {
  queue_url = aws_sqs_queue.bcodmo_checkin_queue.id
  depends_on = [aws_lambda_function.job_manager]

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "__sender_statement",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${aws_iam_role.iam_for_lambda_job_manager.arn}"
      },
      "Action": "SQS:SendMessage",
      "Resource": "${aws_sqs_queue.bcodmo_checkin_queue.arn}"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "s3_pdf" {
  name = "pdf-generator-lambda-s3-${terraform.workspace}"
  role = aws_iam_role.iam_for_lambda_pdf_gen.name
  policy = jsonencode({
    "Statement" : [
      {
      "Sid": "S3Access",
      "Action": [
          "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
          "${aws_s3_bucket.pdf.arn}/*",
          "${aws_s3_bucket.pdf.arn}"
      ]
    },
    {
      "Sid": "CloudWatchLogsAccess",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
    ]
  })
}

resource "aws_iam_role" "iam_for_lambda_pdf_gen" {
  name = "pdf-generator-lambda-s3-${terraform.workspace}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "pdf_generator" {
  filename      = "../../deploy/Archive_test.zip"
  function_name = "pdf-generator-${terraform.workspace}"
  role          = aws_iam_role.iam_for_lambda_pdf_gen.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = filebase64sha256("../../deploy/Archive_test.zip")

  runtime = "python3.8"

  environment {
    variables = {
      FONTCONFIG_PATH =	"fonts",
      LD_LIBRARY_PATH =	"lib",
      basic =	"bin/wkhtmltopdf",
      bucket = aws_s3_bucket.pdf.id
    }
  }
  memory_size = 512
  timeout = 60
}

resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/lambda/${aws_lambda_function.pdf_generator.function_name}"
  retention_in_days = 3
}

resource "aws_iam_role" "iam_for_lambda_job_manager" {
  name = "job-manager-lambda-s3-${terraform.workspace}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "job_manager_policy" {
  name = "job_manager-lambda-${terraform.workspace}"
  role = aws_iam_role.iam_for_lambda_job_manager.name
  policy = jsonencode({
    "Statement" : [
      {
      "Sid": "DynamoDBAccess",
      "Action": [
          "dynamodb:GetItem",
          "dynamodb:PutItem"
      ],
      "Effect": "Allow",
      "Resource": aws_dynamodb_table.bcodmo_jobs.arn
    },
    {
      "Sid": "CloudWatchLogsAccess",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    },
    ]
  })
}

resource "aws_lambda_function" "job_manager" {
  filename      = "../../deploy/Archive_job.zip"
  function_name = "job-manager-${terraform.workspace}"
  role          = aws_iam_role.iam_for_lambda_job_manager.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = filebase64sha256("../../deploy/Archive_job.zip")

  runtime = "python3.8"

  environment {
    variables = {
      bcodmo_jobs = aws_dynamodb_table.bcodmo_jobs.name
    }
  }
  memory_size = 512
  timeout = 60
}

resource "aws_cloudwatch_log_group" "job_manager_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.job_manager.function_name}"
  retention_in_days = 3
}

resource "aws_api_gateway_rest_api" "bco_dmo_api" {
  name = "bcodmo-api-${terraform.workspace}"
  body = templatefile(
    "api.yml",
    {
      pdf_generator_url = aws_lambda_function.pdf_generator.invoke_arn,
      job_manager_url = aws_lambda_function.job_manager.invoke_arn
    }
    )
}

# Lambda
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pdf_generator.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.bco_dmo_api.execution_arn}/*/*/*"
}

resource "aws_lambda_permission" "apigw_job_manager" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.job_manager.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.bco_dmo_api.execution_arn}/*/*/*"
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "*.bco-dmo.org"
  validation_method = "NONE"
  options {
    certificate_transparency_logging_preference = "DISABLED"
  }
}

resource "aws_api_gateway_domain_name" "bcodmo_domain" {
  certificate_arn = aws_acm_certificate.cert.arn
  domain_name     = "${terraform.workspace}.bco-dmo.org"
}

resource "aws_route53_zone" "dev" {
  name = "${terraform.workspace}.bco-dmo.org"

}


resource "aws_route53_record" "bcodmo_dns" {
  name    = aws_api_gateway_domain_name.bcodmo_domain.domain_name
  type    = "A"
  zone_id = aws_route53_zone.dev.id

  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.bcodmo_domain.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.bcodmo_domain.cloudfront_zone_id
  }
}

resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.bcodmo_deploy.id
  rest_api_id   = aws_api_gateway_rest_api.bco_dmo_api.id
  stage_name    = "${terraform.workspace}"
}

resource "aws_api_gateway_deployment" "bcodmo_deploy" {
  rest_api_id = aws_api_gateway_rest_api.bco_dmo_api.id

  depends_on = [aws_api_gateway_rest_api.bco_dmo_api]
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.bco_dmo_api.body,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_usage_plan" "bcodmo_api_usageplan" {
  name = "bcodmo_api_usageplan"

  api_stages {
    api_id = aws_api_gateway_rest_api.bco_dmo_api.id
    stage  = aws_api_gateway_stage.dev.stage_name
  }
}

resource "aws_api_gateway_api_key" "bcodmokey" {
  name = "bcodmokey-${terraform.workspace}"
  description = "API Key for ${terraform.workspace}.bco-dmo.org API"
  enabled = true
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.bcodmokey.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.bcodmo_api_usageplan.id
}

resource "aws_api_gateway_base_path_mapping" "api_mapping" {
  api_id      = aws_api_gateway_rest_api.bco_dmo_api.id
  stage_name  = aws_api_gateway_stage.dev.stage_name
  domain_name = aws_api_gateway_domain_name.bcodmo_domain.domain_name
}
