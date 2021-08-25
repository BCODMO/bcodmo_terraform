resource "aws_ecr_repository" "bcodmo_api" {
  name                 = "bcodmo_api_${terraform.workspace}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_cloudwatch_log_group" "bcodmo_api" {
  name              = "/ecs/bcodmo_api_${terraform.workspace}"
  retention_in_days = "7"

}


resource "aws_ecs_task_definition" "bcodmo_api" {
  family                = "bcodmo_api_${terraform.workspace}"
  container_definitions = <<EOF
[
    {
        "name": "bcodmo_api_container_${terraform.workspace}",
        "image": "${aws_ecr_repository.bcodmo_api.repository_url}:${terraform.workspace == "default" ? "latest" : var.bcodmo_api_version}",
        "portMappings": [
            {
                "containerPort": 8080
            }
        ],
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "${aws_cloudwatch_log_group.bcodmo_api.name}",
                "awslogs-region": "us-east-1",
                "awslogs-stream-prefix": "ecs"
            }
        },
        "environment": [
            {
                "name": "VERSION",
                "value": "${var.bcodmo_api_version}"
            },
            {
                "name": "PORT",
                "value": "8080"
            }
        ]
    }
]

EOF

  task_role_arn      = aws_iam_role.ecs_role.arn
  execution_role_arn = aws_iam_role.ecs_role.arn

  cpu    = "512"
  memory = "1024"

  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  tags = {
    name = terraform.workspace == "default" ? "latest" : var.bcodmo_api_version
  }

}

resource "aws_ecs_service" "bcodmo_api" {
  name                 = "bcodmo_api_${terraform.workspace}"
  launch_type          = "FARGATE"
  force_new_deployment = "true"
  cluster              = aws_ecs_cluster.bcodmo_api.id
  task_definition      = aws_ecs_task_definition.bcodmo_api.arn
  desired_count        = 1
  depends_on           = [aws_iam_role_policy.s3_access_policy, aws_iam_role_policy.ecs_access_policy, aws_alb.bcodmo_api]

  network_configuration {
    subnets          = [aws_default_subnet.default_1a.id, aws_default_subnet.default_1b.id]
    security_groups  = [aws_security_group.bcodmo_api.id]
    assign_public_ip = "true"
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.web.id
    container_name   = "bcodmo_api_container_${terraform.workspace}"
    container_port   = 8080
  }



  lifecycle {
    ignore_changes = [desired_count]
  }


}
