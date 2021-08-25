resource "aws_ecr_repository" "submission_go" {
  name                 = "submission_go_${terraform.workspace}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_cloudwatch_log_group" "submission_go" {
  name              = "/ecs/submission_go_${terraform.workspace}"
  retention_in_days = "7"

}


resource "aws_ecs_task_definition" "submission_go" {
  family                = "submission_go_${terraform.workspace}"
  container_definitions = <<EOF
[
    {
        "name": "submission_go_container_${terraform.workspace}",
        "image": "${aws_ecr_repository.submission_go.repository_url}:${terraform.workspace == "default" ? "latest" : var.submission_version}",
        "portMappings": [
            {
                "containerPort": 8080
            }
        ],
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "${aws_cloudwatch_log_group.submission_go.name}",
                "awslogs-region": "us-east-1",
                "awslogs-stream-prefix": "ecs"
            }
        },
        "environment": [
            {
                "name": "VERSION",
                "value": "${var.submission_version}"
            },
            {
                "name": "MINIO_ENDPOINT",
                "value": "${var.aws_endpoint}"
            },
            {
                "name": "MINIO_ACCESS_KEY",
                "value": "${var.aws_access_key}"
            },
            {
                "name": "MINIO_SECRET_KEY",
                "value": "${var.aws_secret_access_key}"
            },
            {
                "name": "APP_USE_SSL",
                "value": "true"
            },
            {
                "name": "MINIO_SUBMISSIONS_BUCKET",
                "value": "${aws_s3_bucket.submissions.bucket}"
            },
            {
                "name": "MINIO_PROJECTS_BUCKET",
                "value": "${aws_s3_bucket.projects.bucket}"
            },
            {
                "name": "MINIO_PERMISSIONS_BUCKET",
                "value": "${aws_s3_bucket.submissions_permissions.bucket}"
            },
            {

                "name": "LOD_DATASET_ROLES_URI",
                "value": "${var.lod_dataset_roles_uri}"

            },
            {

                "name": "LOD_PROJECT_ROLES_URI",
                "value": "${var.lod_project_roles_uri}"

            },
            {

                "name": "LOD_PROGRAMS_URI",
                "value": "${var.lod_programs_uri}"

            },
            {
                "name": "OFFLINE_DEVELOPMENT",
                "value": "false"
            },
            {
                "name": "SUBMISSION_VALIDATION_URL",
                "value": ""
            },
            {
                "name": "SUBMISSION_VALIDATION_REQUEST_API_KEY",
                "value": "${var.api_request_key}"
            },
            {
                "name": "SUBMISSION_VALIDATION_RESPONSE_API_KEY",
                "value": "${var.api_response_key}"
            },
            {
                "name": "ID_GENERATOR_URL",
                "value": "${var.id_generator_url}"
            },
            {
                "name": "ID_GENERATOR_API_KEY",
                "value": "${var.id_generator_api_key}"
            },
            {
                "name": "AUTH_FORCE_LOGOUT_URL",
                "value": "${var.auth_force_logout_url}"
            },
            {
                "name": "EMAIL_FROM",
                "value": "${var.email_from}"
            },
            {
                "name": "EMAIL_PASSWORD",
                "value": "${var.email_password}"
            },
            {
                "name": "EMAIL_HOST",
                "value": "${var.email_host}"
            },
            {
                "name": "EMAIL_PORT",
                "value": "${var.email_port}"
            },
            {
                "name": "EMAIL_TO",
                "value": "${var.email_to}"
            },
            {
                "name": "AUTH_URL",
                "value": "${var.auth_url}"
            },
            {
                "name": "AUTH_TOKEN_URL",
                "value": "${var.auth_token_url}"
            },
            {
                "name": "AUTH_CLIENT_ID",
                "value": "${var.auth_client_id}"
            },
            {
                "name": "AUTH_CLIENT_SECRET",
                "value": "${var.auth_client_secret}"
            },
            {
                "name": "ORCID_API_URL",
                "value": "${var.orcid_api_url}"
            },
            {
                "name": "ORCID_SAFELIST",
                "value": "${var.orcid_safelist}"
            },
            { "name": "REDMINE_API_URL", "value": "${var.redmine_api_url}" },
            { "name": "REDMINE_API_ACCESS_KEY", "value": "${var.redmine_api_access_key}" },
            { "name": "REDMINE_PROJECT_ID", "value": "${var.redmine_project_id}" },
            { "name": "REDMINE_CATEGORY_ID_PROJECT", "value": "${var.redmine_category_id_project}" },
            { "name": "REDMINE_CATEGORY_ID_DATASET", "value": "${var.redmine_category_id_dataset}" },
            { "name": "REDMINE_CUSTOM_FIELD_ID_SUBMISSION_TOOL_ID", "value": "${var.redmine_custom_field_id_submission_tool_id}" },
            { "name": "REDMINE_CUSTOM_FIELD_ID_SUBMISSION_STATE", "value": "${var.redmine_custom_field_id_submission_state}" },
            { "name": "REDMINE_STATUS_ID", "value": "${var.redmine_status_id}" },
            { "name": "REDMINE_TRACKER_ID", "value": "${var.redmine_tracker_id}" },
            {
                "name": "SUBMISSION_GITHUB_ISSUE_URI",
                "value": "${var.submission_github_issue_uri}"
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
    name = terraform.workspace == "default" ? "latest" : var.submission_version
  }

}

resource "aws_ecs_service" "submission_go" {
  name                 = "submission_go_${terraform.workspace}"
  launch_type          = "FARGATE"
  force_new_deployment = "true"
  cluster              = aws_ecs_cluster.submission.id
  task_definition      = aws_ecs_task_definition.submission_go.arn
  desired_count        = 1
  depends_on           = [aws_iam_role_policy.s3_access_policy, aws_iam_role_policy.ecs_access_policy, aws_alb.submission_go]

  network_configuration {
    subnets          = [aws_default_subnet.default_1a.id, aws_default_subnet.default_1b.id]
    security_groups  = [aws_security_group.submission.id]
    assign_public_ip = "true"
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.web.id
    container_name   = "submission_go_container_${terraform.workspace}"
    container_port   = 8080
  }



  lifecycle {
    ignore_changes = [desired_count]
  }


}
