resource "aws_ecr_repository" "laminar_worker" {
  name                 = "laminar_worker_${terraform.workspace}"
  image_tag_mutability = "MUTABLE"

}

resource "aws_cloudwatch_log_group" "laminar_worker" {
  name              = "/ecs/laminar_worker_${terraform.workspace}"
  retention_in_days = "7"

}

resource "aws_ecs_task_definition" "laminar_worker" {
  family                = "laminar_worker_${terraform.workspace}"
  container_definitions = <<EOF
[
    {
        "name": "laminar_worker_container_${terraform.workspace}",
        "image": "${aws_ecr_repository.laminar_worker.repository_url}:${terraform.workspace == "default" ? "latest" : var.laminar_version}",
        "stopTimeout": 120,
        "mountPoints": [{
            "sourceVolume": "efs_laminar",
            "containerPath": "${var.laminar_tmp_directory}"

        }],
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "${aws_cloudwatch_log_group.laminar_worker.name}",
                "awslogs-region": "us-east-1",
                "awslogs-stream-prefix": "ecs"
            }
        },
        "environment": [
            {
                "name": "C_FORCE_ROOT",
                "value": "true"
            },
            {
                "name": "CELERY_BROKER_URL",
                "value": "${var.redis_url}"
            },
            {
                "name": "CELERY_RESULT_BACKEND",
                "value": "${var.redis_url}"
            },
            {
                "name": "ENVIRONMENT",
                "value": "production"
            },
            {
                "name": "FLASK_APP",
                "value": "app"
            },
            {
                "name": "GITHUB_ISSUE_ACCESS_TOKEN",
                "value": "${var.github_issue_access_token}"
            },
            {
                "name": "LAMINAR_S3_HOST",
                "value": "https://s3.amazonaws.com"
            },
            {
                "name": "LAMINAR_S3_DUMP_BUCKET",
                "value": "${aws_s3_bucket.dump.id}"
            },
            {
                "name": "LAMINAR_S3_LOAD_BUCKET",
                "value": "${aws_s3_bucket.load.id}"
            },
            {
                "name": "LAMINAR_S3_RESULTS_BUCKET",
                "value": "${aws_s3_bucket.results.id}"
            },
            {
                "name": "TMP_DIRECTORY",
                "value": "${var.laminar_tmp_directory}"
            },
            {
                "name": "CELERY_QUEUE",
                "value": "celery"
			}
        ]
    }
]

EOF

  volume {
    name = "efs_laminar"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.efs_volume.id
      root_directory = "/"
    }
  }

  task_role_arn      = aws_iam_role.ecs_role.arn
  execution_role_arn = aws_iam_role.ecs_role.arn

  cpu    = 2048
  memory = 8192


  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  tags = {
    name = terraform.workspace == "default" ? "latest" : var.laminar_version
  }


}

resource "aws_ecs_service" "laminar_worker" {
  name                 = "laminar_worker_${terraform.workspace}"
  launch_type          = "FARGATE"
  platform_version     = "1.4.0"
  force_new_deployment = "true"
  cluster              = aws_ecs_cluster.laminar.id
  task_definition      = aws_ecs_task_definition.laminar_worker.arn
  desired_count        = 0
  depends_on           = [aws_iam_role_policy.s3_access_policy, aws_iam_role_policy.ecs_access_policy]

  network_configuration {
    subnets          = [aws_default_subnet.default_1a.id, aws_default_subnet.default_1b.id]
    security_groups  = [aws_security_group.laminar.id]
    assign_public_ip = "true"


  }



  lifecycle {
    ignore_changes = [desired_count]
  }

}

resource "aws_appautoscaling_target" "laminar_worker_target" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.laminar.name}/${aws_ecs_service.laminar_worker.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "laminar_worker_cpu_low" {
  name               = "laminar-scale-down-${terraform.workspace}"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.laminar_worker_target.resource_id
  scalable_dimension = aws_appautoscaling_target.laminar_worker_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.laminar_worker_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }

  depends_on = [aws_appautoscaling_target.laminar_worker_target]
}


resource "aws_cloudwatch_metric_alarm" "laminar_worker_cpu_low" {
  count               = 1
  alarm_name          = "laminar_worker_cpu_low_${terraform.workspace}"
  alarm_description   = "Managed by Terraform"
  alarm_actions       = ["${aws_appautoscaling_policy.laminar_worker_cpu_low.arn}"]
  comparison_operator = "LessThanOrEqualToThreshold"
  period              = 300
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  statistic           = "Average"
  threshold           = "50"
  dimensions = {
    ClusterName = aws_ecs_cluster.laminar.name
    ServiceName = aws_ecs_service.laminar_worker.name
  }
}

resource "aws_appautoscaling_policy" "laminar_worker_cpu_high" {
  name               = "laminar-scale-up-${terraform.workspace}"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.laminar_worker_target.resource_id
  scalable_dimension = aws_appautoscaling_target.laminar_worker_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.laminar_worker_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }

  depends_on = [aws_appautoscaling_target.laminar_worker_target]
}


resource "aws_cloudwatch_metric_alarm" "laminar_worker_cpu_high" {
  count               = 1
  alarm_name          = "laminar_worker_cpu_high_${terraform.workspace}"
  alarm_description   = "Managed by Terraform"
  alarm_actions       = ["${aws_appautoscaling_policy.laminar_worker_cpu_high.arn}"]
  comparison_operator = "GreaterThanOrEqualToThreshold"
  period              = 60
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  statistic           = "Average"
  threshold           = "50"
  dimensions = {
    ClusterName = aws_ecs_cluster.laminar.name
    ServiceName = aws_ecs_service.laminar_worker.name
  }
}

output "laminar_worker_name" {
  value       = aws_ecs_service.laminar_worker.name
  description = "The name of the laminar worker service"
}
