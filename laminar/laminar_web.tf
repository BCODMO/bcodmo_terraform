resource "aws_ecr_repository" "laminar_web" {
  name                 = "laminar_web_${terraform.workspace}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_cloudwatch_log_group" "laminar_web" {
  name              = "/ecs/laminar_web_${terraform.workspace}"
  retention_in_days = "7"

}


resource "aws_ecs_task_definition" "laminar_web" {
  family                = "laminar_web_${terraform.workspace}"
  container_definitions = <<EOF
[
    {
        "name": "laminar_web_container_${terraform.workspace}",
        "image": "${aws_ecr_repository.laminar_web.repository_url}:${terraform.workspace == "default" ? "latest" : var.laminar_version}",
        "portMappings": [
            {
                "containerPort": 80
            }
        ],
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "${aws_cloudwatch_log_group.laminar_web.name}",
                "awslogs-region": "us-east-1",
                "awslogs-stream-prefix": "ecs"
            }
        },
        "environment": [
            {
                "name": "REACT_APP_LAMINAR_API_URL",
                "value": "https://${var.laminar_api_url}"
            },
            {
                "name": "REACT_APP_ENVIRONMENT",
                "value": "production"
            },
            {
                "name": "REACT_APP_VERSION",
                "value": "${var.laminar_version}"
            },
            {
                "name": "REACT_APP_VERSIONS",
                "value": "${var.laminar_versions}"
            },
            {
                "name": "REACT_APP_LAMINAR_DOCUMENTATION_URL",
                "value": "${var.laminar_documentation_url}"
            },
            {
                "name": "REACT_APP_ORCID_AUTH_CLIENT_ID",
                "value": "${var.laminar_orcid_auth_client_id}"
            },
            {
                "name": "REACT_APP_ORCID_AUTH_URL",
                "value": "${var.laminar_orcid_auth_url}"
            },
            {
                "name": "REACT_APP_LAMINAR_S3_LOAD_URL",
                "value": "https://s3.amazonaws.com"
            },
            {
                "name": "REACT_APP_LAMINAR_S3_DUMP_BUCKET",
                "value": "${aws_s3_bucket.dump.id}"
            },
            {
                "name": "REACT_APP_LAMINAR_S3_LOAD_BUCKET",
                "value": "${aws_s3_bucket.load.id}"
            },
            {
                "name": "REACT_APP_SUBMISSION_S3_BUCKET",
                "value": "${var.laminar_submission_s3_bucket}"
            },
            {
                "name": "REACT_APP_SUBMISSION_BASE_URL",
                "value": "${var.laminar_submission_base_url}"
            },
            {
                "name": "REACT_APP_REDMINE_ISSUE_BASE_URL",
                "value": "${var.laminar_redmine_issue_base_url}"
            }
        ]
    }
]

EOF

  task_role_arn      = aws_iam_role.ecs_role.arn
  execution_role_arn = aws_iam_role.ecs_role.arn

  cpu    = "256"
  memory = "512"

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  tags = {
    name = terraform.workspace == "default" ? "latest" : var.laminar_version
  }

}

resource "aws_ecs_service" "laminar_web" {
  name                 = "laminar_web_${terraform.workspace}"
  launch_type          = "FARGATE"
  force_new_deployment = "true"
  cluster              = aws_ecs_cluster.laminar.id
  task_definition      = aws_ecs_task_definition.laminar_web.arn
  desired_count        = 1
  depends_on           = [aws_iam_role_policy.s3_access_policy, aws_iam_role_policy.ecs_access_policy, aws_alb.laminar_web]

  network_configuration {
    subnets          = [aws_default_subnet.default_1a.id, aws_default_subnet.default_1b.id]
    security_groups  = [aws_security_group.laminar.id]
    assign_public_ip = "true"
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.web.id
    container_name   = "laminar_web_container_${terraform.workspace}"
    container_port   = 80
  }



  lifecycle {
    ignore_changes = [desired_count]
  }


}
