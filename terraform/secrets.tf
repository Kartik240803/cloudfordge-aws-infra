resource "random_password" "db" {
  length  = 32
  special = false
}

resource "random_password" "nextauth" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "app" {
  name                    = "${var.environment}-${var.name}-creds"
  recovery_window_in_days = var.secret_recovery_window_days
}

# Both values live in Terraform state. Keep the state bucket private and encrypted.
resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    DATABASE_URL    = "mysql://${var.db_username}:${random_password.db.result}@${aws_db_instance.main.address}:3306/${var.db_name}"
    NEXTAUTH_SECRET = random_password.nextauth.result
  })
}
