# ==============================================================================
# modules/networking/security_groups.tf
# Security groups owned by the networking module.
#
# Only the VPC Endpoint SG lives here — it is referenced directly by
# endpoints.tf and must remain co-located with the endpoint resources.
#
# Service SGs (ALB, ECS, Lambda, RDS) are defined in their respective modules:
#   - ecs/security_groups.tf     (ALB + ECS tasks)
#   - lambda/security_groups.tf  (Lifecycle Lambda)
#   - rds/security_groups.tf     (PostgreSQL)
# ==============================================================================

# sg-vpce: receives HTTPS from ECS and Lambda; attached to all interface endpoints
resource "aws_security_group" "vpce" {
  name        = "${var.project_name}-${var.environment}-sg-vpce"
  description = "VPC Endpoints — inbound HTTPS from ECS and Lambda"
  vpc_id      = aws_vpc.main.id

  # Ingress rules are added by ECS and Lambda modules as aws_security_group_rule
  # resources after those modules create their own SGs. The networking module
  # cannot reference ECS/Lambda SG IDs here without creating circular dependencies.
  # Instead, we allow inbound HTTPS from within the VPC CIDR — the ECS and Lambda
  # SGs restrict outbound to this specific SG, preserving the least-privilege intent.
  ingress {
    description = "HTTPS from private app subnets (ECS tasks and Lambda)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-sg-vpce"
  }
}
