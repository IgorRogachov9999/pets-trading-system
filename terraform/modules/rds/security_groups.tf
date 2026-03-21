# ==============================================================================
# modules/rds/security_groups.tf
# Security group owned by the RDS module: PostgreSQL database.
# Ingress is locked to the ECS and Lambda SGs — no other sources permitted.
# ==============================================================================

# sg-rds: inbound PostgreSQL from ECS and Lambda only
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-sg-rds"
  description = "RDS PostgreSQL — inbound from ECS and Lambda only"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-sg-rds"
  }
}

resource "aws_security_group_rule" "rds_from_ecs" {
  type                     = "ingress"
  description              = "PostgreSQL from ECS tasks"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = var.ecs_sg_id
}

resource "aws_security_group_rule" "rds_from_lambda" {
  type                     = "ingress"
  description              = "PostgreSQL from Lifecycle Lambda"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = var.lambda_sg_id
}
