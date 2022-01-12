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

    prefix = "*"

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
    },
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

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
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

resource "aws_api_gateway_rest_api" "bco_dmo_api" {
  name = "bcodmo-api-${terraform.workspace}"
}

# Remove this. Use open API specification for adding future paths.
resource "aws_api_gateway_resource" "bcodmo_generate" {
  rest_api_id = "${aws_api_gateway_rest_api.bco_dmo_api.id}"
  parent_id   = "${aws_api_gateway_rest_api.bco_dmo_api.root_resource_id}"
  path_part   = "generatepdf"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.bco_dmo_api.id
  resource_id   = aws_api_gateway_resource.bcodmo_generate.id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true
  request_parameters = {
    "method.request.querystring.url" = true
  }
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.bco_dmo_api.id
  resource_id             = aws_api_gateway_resource.bcodmo_generate.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.pdf_generator.invoke_arn
  request_parameters = {
        "integration.request.querystring.url" = "method.request.querystring.url"
    }
}

# Lambda
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pdf_generator.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.bco_dmo_api.execution_arn}/*/${aws_api_gateway_method.method.http_method}${aws_api_gateway_resource.bcodmo_generate.path}"
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

  depends_on = [aws_api_gateway_method.method]
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.bcodmo_generate.id,
      aws_api_gateway_method.method.id,
      aws_api_gateway_integration.integration.id,
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
