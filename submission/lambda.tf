resource "aws_iam_role_policy" "lambda_logs" {
  name = "submission-lambda-logs-${terraform.workspace}"
  role = aws_iam_role.iam_for_lambda.name
  policy = jsonencode({
    "Statement" : [
      {
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:logs:*:*:*",
      },
    ]
  })
}

resource "aws_iam_role_policy" "ecs" {
  name = "submission-lambda-s3-${terraform.workspace}"
  role = aws_iam_role.iam_for_lambda.name
  policy = jsonencode({
    "Statement" : [
      {
        "Action" : [
          "s3:*"
        ],
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:s3:::${aws_s3_bucket.submissions.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.submissions.bucket}/*",
          "arn:aws:s3:::${aws_s3_bucket.projects.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.projects.bucket}/*"
        ]
      },
    ]
  })
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_submission_lambda_${terraform.workspace}"

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


resource "aws_lambda_function" "submission-unzip" {
  filename      = "../../../submission/bcodmo_submission/lambda/function-submission-unzip-${terraform.workspace}.zip"
  function_name = "submission-unzip-${terraform.workspace}"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = filebase64sha256("../../../submission/bcodmo_submission/lambda/function-submission-unzip-${terraform.workspace}.zip")

  runtime = "python3.6"
  timeout = 60

  environment {
    variables = {
    }
  }
  depends_on = [aws_iam_role_policy.lambda_logs]
}
