# ==============================================================================
# modules/ecs/security_groups.tf
# Security groups owned by the ECS module: ALB and ECS tasks.
# Cross-referencing rules use separate aws_security_group_rule resources to
# avoid Terraform cycle errors (alb <-> ecs mutual references).
# ==============================================================================

# sg-alb: receives HTTPS from internet, forwards to ECS tasks on 8080
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-sg-alb"
  description = "Application Load Balancer - inbound HTTPS, outbound to ECS"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-sg-alb"
  }
}

# sg-ecs: receives traffic from ALB, connects to RDS and VPC endpoints
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-${var.environment}-sg-ecs"
  description = "ECS Fargate Trading API - inbound from ALB, outbound to RDS and VPC endpoints"
  vpc_id      = var.vpc_id

  egress {
    description = "PostgreSQL to RDS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    # RDS SG ID is not known at ECS module creation time.
    # This egress allows port 5432 to any destination within the VPC.
    # The RDS SG ingress rule (defined in rds/security_groups.tf) restricts
    # inbound to this specific SG, achieving the same least-privilege result.
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    description     = "HTTPS to VPC endpoints"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.sg_vpce_id]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-sg-ecs"
  }
}

# Cross-referencing rules — separate resources to break the alb <-> ecs cycle
resource "aws_security_group_rule" "alb_egress_to_ecs" {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.ecs.id
  description              = "HTTP to ECS tasks"
}

resource "aws_security_group_rule" "ecs_ingress_from_alb" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs.id
  source_security_group_id = aws_security_group.alb.id
  description              = "HTTP from ALB"
}
