resource "aws_ecs_cluster" "submission" {
  name = "submission-${var.environment[terraform.workspace]}"
}

resource "aws_iam_role_policy" "secrets_access_policy" {
  name = "laminar_secrets_access_policy_${var.environment[terraform.workspace]}"
  role = aws_iam_role.ecs_role.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
            "secretsmanager:GetResourcePolicy",
            "secretsmanager:GetSecretValue",
            "secretsmanager:DescribeSecret",
            "secretsmanager:ListSecretVersionIds"
        ],
        "Effect": "Allow",
        "Resource": [
            "${aws_secretsmanager_secret.checkin_api_key.arn}",
            "${aws_secretsmanager_secret.redmine_api_access_key.arn}",
            "${aws_secretsmanager_secret.id_generator_api_key.arn}"
        ]
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "s3_access_policy" {
  name = "submission_s3_access_policy_${var.environment[terraform.workspace]}"
  role = aws_iam_role.ecs_role.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "s3:*"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "ecs_access_policy" {
  name = "submission_ecs_access_policy_${var.environment[terraform.workspace]}"
  role = aws_iam_role.ecs_role.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
               "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role" "ecs_role" {
  name = "submission_ecs_role_${var.environment[terraform.workspace]}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
