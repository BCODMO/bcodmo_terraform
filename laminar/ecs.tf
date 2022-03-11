resource "aws_ecs_cluster" "laminar" {
  name = "laminar-${var.environment[terraform.workspace]}"
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
            "${aws_secretsmanager_secret.github_access_token.arn}"
        ]
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "efs_access_policy" {
  name = "laminar_efs_access_policy_${var.environment[terraform.workspace]}"
  role = aws_iam_role.ecs_role.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "elasticfilesystem:*"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "s3_access_policy" {
  name = "laminar_s3_access_policy_${var.environment[terraform.workspace]}"
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

resource "aws_iam_role_policy" "ecs_update_access_policy" {
  name = "laminar_ecs_update_access_policy_${var.environment[terraform.workspace]}"
  role = aws_iam_role.ecs_role.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
                "ecs:*"
        ],
        "Effect": "Allow",
        "Resource": "*",
        "Condition": {
            "StringEquals": { "ecs:cluster": "${aws_ecs_cluster.laminar.arn}" }
        }
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "ecs_access_policy" {
  name = "laminar_ecs_access_policy_${var.environment[terraform.workspace]}"
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
  name = "laminar_ecs_role_${var.environment[terraform.workspace]}"

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
