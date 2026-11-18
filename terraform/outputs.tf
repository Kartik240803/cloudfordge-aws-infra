output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "app_url" {
  value = local.app_url
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "rds_endpoint" {
  value = aws_db_instance.main.address
}

output "secret_arn" {
  value = aws_secretsmanager_secret.app.arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "codebuild_project_name" {
  value = local.codebuild_enabled ? aws_codebuild_project.image[0].name : null
}

output "run_migration_command" {
  description = "One-off migration + seed task. Run once after the image is pushed."
  value = join(" ", [
    "aws ecs run-task",
    "--region ${var.region}",
    "--cluster ${aws_ecs_cluster.main.name}",
    "--launch-type FARGATE",
    "--task-definition ${aws_ecs_task_definition.app.family}",
    "--network-configuration 'awsvpcConfiguration={subnets=[${join(",", aws_subnet.app[*].id)}],securityGroups=[${aws_security_group.app.id}],assignPublicIp=DISABLED}'",
    "--overrides '{\"containerOverrides\":[{\"name\":\"app\",\"environment\":[{\"name\":\"APP_MODE\",\"value\":\"migrate\"},{\"name\":\"SEED_DB\",\"value\":\"true\"}]}]}'",
  ])
}

output "images_bucket_name" {
  value = aws_s3_bucket.images.bucket
}
