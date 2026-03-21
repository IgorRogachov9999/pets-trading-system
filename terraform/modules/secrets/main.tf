# ==============================================================================
# modules/secrets/main.tf
# Secrets Manager secrets with placeholder values.
# Real values are populated post-RDS provisioning or via Secrets Manager rotation.
# ECS and Lambda retrieve secrets at runtime — no credentials in task definitions.
# ==============================================================================

# DB connection secret
resource "aws_secretsmanager_secret" "db_connection" {
  name                    = "${var.project_name}/db-connection"
  description             = "PostgreSQL connection details for the Trading API and Lifecycle Lambda."
  recovery_window_in_days = 0 # Immediate deletion allowed in dev; set to 30 in demo

  tags = {
    Name = "${var.project_name}-${var.environment}-secret-db-connection"
  }
}

resource "aws_secretsmanager_secret_version" "db_connection" {
  secret_id = aws_secretsmanager_secret.db_connection.id

  secret_string = jsonencode({
    host     = ""
    port     = "5432"
    dbname   = "petsdb"
    username = "app"
    # password intentionally blank — populated after RDS provisioning or via
    # Secrets Manager automatic rotation with RDS integration.
    password = ""
  })

  # Prevent Terraform from overwriting the secret after initial creation
  # (rotation lambda or manual update may have changed it)
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# App config secret (Cognito IDs known after Cognito module applies)
resource "aws_secretsmanager_secret" "app_config" {
  name                    = "${var.project_name}/app-config"
  description             = "Application configuration: Cognito User Pool ID and Client ID."
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-${var.environment}-secret-app-config"
  }
}

resource "aws_secretsmanager_secret_version" "app_config" {
  secret_id = aws_secretsmanager_secret.app_config.id

  secret_string = jsonencode({
    cognito_user_pool_id = ""
    cognito_client_id    = ""
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
