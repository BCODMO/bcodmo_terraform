resource "aws_efs_file_system" "checkin_efs" {
  creation_token = "bcodmo-checkin-efs-${terraform.workspace}"
  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }

}

resource "aws_efs_mount_target" "checkin_cache1b" {
  file_system_id  = aws_efs_file_system.checkin_efs.id
  subnet_id       = aws_subnet.bcodmo_checkin_us_east_1b.id
  security_groups = [aws_security_group.bcodmo_checkin_efs_sg.id]
}

resource "aws_efs_mount_target" "checkin_cache1a" {
  file_system_id  = aws_efs_file_system.checkin_efs.id
  subnet_id       = aws_subnet.bcodmo_checkin_us_east_1a.id
  security_groups = [aws_security_group.bcodmo_checkin_efs_sg.id]
}

resource "aws_ecs_cluster" "checkin" {
  name = "bcodmo-checkin-${terraform.workspace}"
}

resource "aws_iam_role" "checkin_ecs_role" {
  name = "checkin_ecs_role_${terraform.workspace}"

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

resource "aws_ecr_repository" "bcodmo_checkin_ecr" {
  name                 = "bcodmo_checkin_${terraform.workspace}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_cloudwatch_log_group" "bcodmo_checkin_server" {
  name              = "/ecs/bcodmo_checkin_${terraform.workspace}"
  retention_in_days = "7"

}

resource "aws_iam_role_policy" "checkin_iam_policy" {
  name = "bcodmo_checkin_iam_policy_${terraform.workspace}"
  role = aws_iam_role.checkin_ecs_role.id

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
      },
      {
        "Action": [
          "s3:*"
        ],
        "Effect": "Allow",
        "Resource": "*"
      },
      {
        "Action": [
               "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage"
        ],
        "Effect": "Allow",
        "Resource": "*"
      },
      {
        "Action": [
                "sqs:*"
            ],
        "Effect": "Allow",
        "Resource": "*"
      },
      {
        "Action": [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:Query",
            "dynamodb:UpdateItem"
        ],
        "Effect": "Allow",
        "Resource": "${aws_dynamodb_table.bcodmo_jobs.arn}"
      },
      {
        "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:*:*:*",
        "Effect": "Allow"
      }
    ]
  }
  EOF
}

resource "aws_ecs_task_definition" "bcodmo_checkin" {
  family                = "bcodmo_checkin_${terraform.workspace}"
  container_definitions = <<EOF
[
    {
        "name": "bcodmo_checkin_container_${terraform.workspace}",
        "image": "${aws_ecr_repository.bcodmo_checkin_ecr.repository_url}:${var.checkin_version}",
        "portMappings": [],
        "mountPoints": [{
            "sourceVolume": "efs_checkin",
            "containerPath": "${var.checkin_tmp_directory}"

        }],
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "${aws_cloudwatch_log_group.bcodmo_checkin_server.name}",
                "awslogs-region": "us-east-1",
                "awslogs-stream-prefix": "ecs"
            }
        },
        "environment": [
            {
                "name": "SQSVisibilityTimeout",
                "value": "600"
            },
            {
                "name": "AWS_REGION",
                "value": "us-east-1"
            },
            {
                "name": "BcodmoS3",
                "value": "${aws_s3_bucket.bcodmo_checkin_s3.id}"
            },
            {
                "name": "JobQueueURL",
                "value": "${aws_sqs_queue.bcodmo_checkin_queue.url}"
            },
            {
                "name": "JobDB",
                "value": "${aws_dynamodb_table.bcodmo_jobs.id}"
            },
            {
                "name": "TMP_DIRECTORY",
                "value": "${var.checkin_tmp_directory}"
            }
        ]
    }
]

EOF

  volume {
    name = "efs_checkin"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.checkin_efs.id
      root_directory = "/"
      transit_encryption      = "ENABLED"
      authorization_config {
        iam             = "ENABLED"
      }
    }
  }
  task_role_arn      = aws_iam_role.checkin_ecs_role.arn
  execution_role_arn = aws_iam_role.checkin_ecs_role.arn

  cpu    = 4096
  memory = 8192

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  tags = {
    name = terraform.workspace == "default" ? "latest" : var.checkin_version
  }
}

resource "aws_ecs_service" "bcodmo_checkin" {
  name                 = "bcodmo_checkin_${terraform.workspace}"
  launch_type          = "FARGATE"
  force_new_deployment = "true"
  cluster              = aws_ecs_cluster.checkin.id
  task_definition      = aws_ecs_task_definition.bcodmo_checkin.arn
  desired_count        = 0
  depends_on           = [aws_iam_role_policy.checkin_iam_policy]

  network_configuration {
    subnets          = [aws_subnet.bcodmo_checkin_us_east_1a.id, aws_subnet.bcodmo_checkin_us_east_1b.id]
    security_groups  = [aws_security_group.bcodmo_checkin_ecs_sg.id]
    assign_public_ip = "true"
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_appautoscaling_target" "checkin_ecs_target" {
  max_capacity = 10
  min_capacity = 0
  resource_id = "service/${aws_ecs_cluster.checkin.name}/${aws_ecs_service.bcodmo_checkin.name}"
#   role_arn = data.aws_iam_role.ecs_autoscaling_role.arn
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace = "ecs"
}

resource "aws_appautoscaling_policy" "checkin_scale_up" {
  policy_type = "StepScaling"
  name = "bcodmo-checkin-scale-up-${terraform.workspace}"
  resource_id = aws_appautoscaling_target.checkin_ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.checkin_ecs_target.scalable_dimension
  service_namespace = aws_appautoscaling_target.checkin_ecs_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type = "ChangeInCapacity"
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      metric_interval_upper_bound = 1
      scaling_adjustment = 1
    }
    step_adjustment {
      metric_interval_lower_bound = 1
      metric_interval_upper_bound = 7
      scaling_adjustment = 2
    }
    step_adjustment {
      metric_interval_lower_bound = 7
      metric_interval_upper_bound = 31
      scaling_adjustment = 4
    }
    step_adjustment {
      metric_interval_lower_bound = 31
      scaling_adjustment = 8
    }
  }
}

resource "aws_appautoscaling_policy" "checkin_scale_down" {
  policy_type = "StepScaling"
  name = "bcodmo-checkin-scale-down-${terraform.workspace}"
  resource_id = aws_appautoscaling_target.checkin_ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.checkin_ecs_target.scalable_dimension
  service_namespace = aws_appautoscaling_target.checkin_ecs_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type = "ExactCapacity"
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment = 0
    }

  }
}

resource "aws_cloudwatch_metric_alarm" "sqs_scale_up" {
  alarm_name = "bcodmo-checkin-ScaleUp-${terraform.workspace}"

  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "1"
  metric_name = "ApproximateNumberOfMessagesVisible"
  namespace = "AWS/SQS"
  period = "60"
  threshold = "1"
  statistic = "Maximum"
  alarm_description = "Checkin-SQS-ScaleUp-${terraform.workspace}"
  insufficient_data_actions = []
  treat_missing_data  = "notBreaching"
  alarm_actions = [
    aws_appautoscaling_policy.checkin_scale_up.arn]

  depends_on           = [aws_appautoscaling_policy.checkin_scale_up]

  dimensions = {
    QueueName = aws_sqs_queue.bcodmo_checkin_queue.name
  }
}

resource "aws_cloudwatch_metric_alarm" "sqs_scale_down" {
  alarm_name = "bcodmo-checkin-ScaleDown-${terraform.workspace}"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "5"
  threshold = "0"
  alarm_description = "SQS-ScaleDown-${terraform.workspace}"
  treat_missing_data  = "notBreaching"
  depends_on           = [aws_appautoscaling_policy.checkin_scale_down]
  alarm_actions = [
    aws_appautoscaling_policy.checkin_scale_down.arn]

metric_query {
    id          = "e1"
    expression  = "IF(m1 OR m2, 1, 0)"
    label       = "Empty Queue"
    return_data = "true"
  }

  metric_query {
    id = "m1"

    metric {
      metric_name = "ApproximateNumberOfMessagesNotVisible"
      namespace   = "AWS/SQS"
      period      = "60"
      stat        = "Maximum"

      dimensions = {
        QueueName = aws_sqs_queue.bcodmo_checkin_queue.name
      }
    }
  }

  metric_query {
    id = "m2"

    metric {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      period      = "60"
      stat        = "Maximum"

      dimensions = {
        QueueName = aws_sqs_queue.bcodmo_checkin_queue.name
      }
    }
  }
}