# A script to forgot the state of ECS tasks so that they are not deleted
# https://github.com/terraform-providers/terraform-provider-aws/issues/258
terraform state rm aws_ecs_task_definition.submission_go
