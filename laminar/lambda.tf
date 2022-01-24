resource "aws_iam_role_policy" "logs" {
  name = "laminar-lambda-logs-${terraform.workspace}"
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
  name = "laminar-lambda-ecs-${terraform.workspace}"
  role = aws_iam_role.iam_for_lambda.name
  policy = jsonencode({
    "Statement" : [
      {
        "Action" : [
          "ecs:RunTask",
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:ecs:*:*:service/${aws_ecs_cluster.laminar.name}/${aws_ecs_service.laminar_worker.name}",
      },
      {
        "Action" : [
          "ecs:RunTask",
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:ecs:*:*:service/${aws_ecs_cluster.laminar.name}/${aws_ecs_service.laminar_worker_big.name}",
      }
    ]
  })
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_laminar_lambda_${terraform.workspace}"

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

resource "aws_cloudwatch_event_rule" "laminar_up" {
  name                = "laminar-every-workday-morning-${terraform.workspace}"
  description         = "Fires every morning before the workday"
  schedule_expression = "cron(45 11 ? * MON-FRI *)"
  lifecycle {
    ignore_changes = [is_enabled]
  }
}

resource "aws_cloudwatch_event_target" "laminar_up" {
  rule      = aws_cloudwatch_event_rule.laminar_up.name
  target_id = "laminar-worker-up-${terraform.workspace}"
  arn       = aws_lambda_function.laminar_worker_up.arn
}

resource "aws_lambda_permission" "laminar_up" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.laminar_worker_up.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.laminar_up.arn
}


resource "aws_lambda_function" "laminar_worker_up" {
  filename      = "../laminar_server/lambda/function-laminar-worker-up-${terraform.workspace}.zip"
  function_name = "laminar-worker-up-${terraform.workspace}"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = filebase64sha256("../../laminar_server/lambda/function-laminar-worker-up-${terraform.workspace}.zip")

  runtime = "python3.6"
  timeout = 60

  environment {
    variables = {
      ecs_cluster_name = aws_ecs_cluster.laminar.name
      ecs_service_name = aws_ecs_service.laminar_worker.name
    }
  }
  depends_on = [aws_iam_role_policy.logs]
}

resource "aws_cloudwatch_event_rule" "laminar_down" {
  name                = "laminar-every-workday-evening-${terraform.workspace}"
  description         = "Fires every evening after the workday"
  schedule_expression = "cron(1 23 ? * MON-FRI *)"
}

resource "aws_cloudwatch_event_target" "laminar_down" {
  rule      = aws_cloudwatch_event_rule.laminar_down.name
  target_id = "laminar-worker-down-${terraform.workspace}"
  arn       = aws_lambda_function.laminar_worker_down.arn
}
resource "aws_cloudwatch_event_target" "laminar_big_down" {
  rule      = aws_cloudwatch_event_rule.laminar_down.name
  target_id = "laminar-worker-big-down-${terraform.workspace}"
  arn       = aws_lambda_function.laminar_worker_big_down.arn
}

resource "aws_lambda_permission" "laminar_down" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.laminar_worker_down.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.laminar_down.arn
}

resource "aws_lambda_permission" "laminar_big_down" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.laminar_worker_big_down.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.laminar_down.arn
}


resource "aws_lambda_function" "laminar_worker_down" {
  filename      = "../laminar_server/lambda/function-laminar-worker-down-${terraform.workspace}.zip"
  function_name = "laminar-worker-down-${terraform.workspace}"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = filebase64sha256("../../laminar_server/lambda/function-laminar-worker-down-${terraform.workspace}.zip")

  runtime = "python3.6"

  timeout = 60

  environment {
    variables = {
      ecs_cluster_name      = aws_ecs_cluster.laminar.name
      ecs_service_name      = aws_ecs_service.laminar_worker.name
      CELERY_BROKER_URL     = local.redis_address
      CELERY_RESULT_BACKEND = local.redis_address
    }
  }
  depends_on = [aws_iam_role_policy.logs]
}

resource "aws_lambda_function" "laminar_worker_big_down" {
  filename      = "../laminar_server/lambda/function-laminar-worker-down-${terraform.workspace}.zip"
  function_name = "laminar-worker-big-down-${terraform.workspace}"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = filebase64sha256("../../laminar_server/lambda/function-laminar-worker-down-${terraform.workspace}.zip")

  runtime = "python3.6"

  timeout = 60

  environment {
    variables = {
      ecs_cluster_name      = aws_ecs_cluster.laminar.name
      ecs_service_name      = aws_ecs_service.laminar_worker_big.name
      CELERY_BROKER_URL     = local.redis_address
      CELERY_RESULT_BACKEND = local.redis_address
    }
  }
  depends_on = [aws_iam_role_policy.logs]
}
