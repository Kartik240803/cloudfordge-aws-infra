locals {
  app_url = var.app_url != "" ? var.app_url : (var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_lb.main.dns_name}")

  environment = merge(
    {
      NODE_ENV     = "production"
      PORT         = tostring(var.app_port)
      HOSTNAME     = "0.0.0.0"
      NEXTAUTH_URL = local.app_url
      APP_URL      = local.app_url
      DB_HOST      = aws_db_instance.main.address
      DB_PORT      = "3306"
      DB_NAME      = var.db_name
      LOG_TO_FILE  = "false"
    },
    var.admin_email != "" ? { ADMIN_EMAIL = var.admin_email } : {},
    var.extra_environment,
  )

  secret_keys = concat(["DATABASE_URL", "NEXTAUTH_SECRET"], var.extra_secret_keys)
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_cluster" "main" {
  name = "${local.prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.prefix}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  volume {
    name = "uploads"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.uploads.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.uploads.id
        iam             = "DISABLED"
      }
    }
  }

  container_definitions = jsonencode([{
    name      = "app"
    image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
    essential = true

    portMappings = [{ containerPort = var.app_port, protocol = "tcp" }]

    environment = [for k, v in local.environment : { name = k, value = v }]
    secrets = [for k in local.secret_keys : {
      name      = k
      valueFrom = "${aws_secretsmanager_secret.app.arn}:${k}::"
    }]

    mountPoints = [{
      sourceVolume  = "uploads"
      containerPath = "/app/public/uploads"
      readOnly      = false
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])

  depends_on = [aws_secretsmanager_secret_version.app]
}

resource "aws_ecs_service" "app" {
  name            = "${local.prefix}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  health_check_grace_period_seconds  = var.health_check_grace_seconds
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  enable_execute_command             = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = aws_subnet.app[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.app_port
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener.https,
    aws_efs_mount_target.uploads,
    aws_iam_role_policy_attachment.task_execution_managed,
    aws_iam_role_policy.read_secrets,
  ]
}
