# ==============================================================================
# modules/ecs/security_groups.tf
# Security groups owned by the ECS module: ECS tasks only.
# NLB does not require a security group (traffic is CIDR-based).
# ==============================================================================

# sg-ecs: receives traffic from NLB (VPC CIDR), connects to RDS and VPC endpoints
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-${var.environment}-sg-ecs"
  description = "ECS Fargate Trading API - inbound from NLB, outbound to RDS and VPC endpoints"
  vpc_id      = var.vpc_id

  egress {
    description = "PostgreSQL to RDS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
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

# NLB does not use security groups — allow inbound on port 8080 from the VPC CIDR.
# The internal NLB forwards traffic from its private subnets, which are within the VPC.
resource "aws_security_group_rule" "ecs_ingress_from_nlb" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  security_group_id = aws_security_group.ecs.id
  cidr_blocks       = [var.vpc_cidr_block]
  description       = "HTTP from internal NLB"
}
