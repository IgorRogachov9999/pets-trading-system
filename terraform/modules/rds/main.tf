# ==============================================================================
# modules/rds/main.tf
# RDS PostgreSQL 16 — ACID-critical financial database.
# IAM authentication enabled; no password in env vars (ADR-003 + ADR-006).
# Architecture reference: docs/architecture/07-deployment-view.md
# ==============================================================================

resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-${var.environment}-db-subnet-group"
  description = "Private DB subnets for ${var.project_name} RDS instance"
  subnet_ids  = var.db_subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

resource "aws_db_parameter_group" "postgres16" {
  name        = "${var.project_name}-${var.environment}-pg16"
  family      = "postgres16"
  description = "Custom parameter group for ${var.project_name} PostgreSQL 16"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-pg16-params"
  }
}

resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  db_name  = "petsdb"
  username = "dbadmin"
  # Password managed via Secrets Manager — stored separately, not in TF state.
  # Set manage_master_user_password = true for RDS-managed rotation (AWS provider >= 5.x).
  manage_master_user_password = true

  # Storage
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  # IAM authentication (passwordless from ECS/Lambda)
  iam_database_authentication_enabled = true

  # Parameter group
  parameter_group_name = aws_db_parameter_group.postgres16.name

  # Backup and maintenance
  backup_retention_period   = 7
  backup_window             = "03:00-04:00"
  maintenance_window        = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot     = true
  delete_automated_backups  = true

  # Performance Insights (free tier: 7-day retention)
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # Protect demo from accidental deletion; dev can be destroyed freely
  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-postgres"
  }
}
