resource "aws_ecr_repository" "laminar_app" {
  name                 = "laminar_app_${terraform.workspace}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_cloudwatch_log_group" "laminar_app" {
  name              = "/ecs/laminar_app_${terraform.workspace}"
  retention_in_days = "7"

}


resource "aws_ecs_task_definition" "laminar_app" {
  family                = "laminar_app_${terraform.workspace}"
  container_definitions = <<EOF
[
    {
        "name": "laminar_app_container_${terraform.workspace}",
        "image": "${aws_ecr_repository.laminar_app.repository_url}:${terraform.workspace == "default" ? "latest" : var.laminar_version}",
        "portMappings": [
            {
                "containerPort": 5300,
                "hostPort": 5300,
                "protocol": "tcp"
            }
        ],
        
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "${aws_cloudwatch_log_group.laminar_app.name}",
                "awslogs-region": "us-east-1",
                "awslogs-stream-prefix": "ecs"
            }
        },
        "environment": [
            {
                "name": "CELERY_BROKER_URL",
                "value": "${local.redis_address}"
            },
            {
                "name": "CELERY_RESULT_BACKEND",
                "value": "${local.redis_address}"
            },
            {
                "name": "DEBUG",
                "value": "false"
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
                "name": "ECS_CLUSTER_NAME",
                "value": "${aws_ecs_cluster.laminar.name}"
            },
            {
                "name": "ECS_SERVICE_NAME",
                "value": "${aws_ecs_service.laminar_worker.name}"
            },
            {
                "name": "ECS_SERVICE_NAME_BIG",
                "value": "${aws_ecs_service.laminar_worker_big.name}"
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
                "name": "LAMINAR_S3_HISTORY_BUCKET",
                "value": "${aws_s3_bucket.history.id}"
            },
            {
                "name": "SUBMISSION_BUCKET",
                "value": "${var.laminar_submission_s3_bucket}"
            },
            {
                "name": "GITHUB_ISSUE_ACCESS_TOKEN",
                "value": "${var.github_issue_access_token}"
            },
            {
                "name": "ORCID_CLIENT_ID",
                "value": "${var.laminar_orcid_auth_client_id}"
            },
            {
                "name": "ORCID_JWKS_ENDPOINT",
                "value": "${var.laminar_orcid_jwks_endpoint}"
            },
            {
                "name": "ORCID_API_URL",
                "value": "${var.laminar_orcid_api_url}"
            },
            {
                "name": "BIG_WORKER_QUEUE_NAME",
                "value": "worker_big"
            },
            {
                "name": "PORT",
                "value": "5300"
            },
            {
                "name": "TMP_DIRECTORY",
                "value": "/laminar"
            }
        ]
    }
]

EOF

  task_role_arn      = aws_iam_role.ecs_role.arn
  execution_role_arn = aws_iam_role.ecs_role.arn

  cpu    = terraform.workspace == "default" ? 256 : 512
  memory = terraform.workspace == "default" ? 1024 : 2048

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  tags = {
    name = terraform.workspace == "default" ? "latest" : var.laminar_version
  }
}




resource "aws_ecs_service" "laminar_app" {
  name                 = "laminar_app_${terraform.workspace}"
  launch_type          = "FARGATE"
  force_new_deployment = "true"
  cluster              = aws_ecs_cluster.laminar.id
  task_definition      = aws_ecs_task_definition.laminar_app.arn
  desired_count        = 1
  depends_on           = [aws_iam_role_policy.s3_access_policy, aws_iam_role_policy.ecs_access_policy, aws_alb.laminar_app]

  network_configuration {
    subnets          = [aws_default_subnet.default_1a.id, aws_default_subnet.default_1b.id]
    security_groups  = [aws_security_group.laminar.id]
    assign_public_ip = "true"
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.app.id
    container_name   = "laminar_app_container_${terraform.workspace}"
    container_port   = 5300
  }



  lifecycle {
    ignore_changes = [desired_count]
  }
}
