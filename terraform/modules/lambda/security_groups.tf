# ==============================================================================
# modules/lambda/security_groups.tf
# Security group owned by the Lambda module: Lifecycle Engine.
# No inbound rules — Lambda is invoked by EventBridge Scheduler, not network.
# ==============================================================================

# sg-lambda: no inbound, outbound to RDS and VPC endpoints
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-sg-lambda"
  description = "Lifecycle Lambda - outbound only to RDS and VPC endpoints"
  vpc_id      = var.vpc_id

  egress {
    description = "PostgreSQL to RDS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    # RDS SG ID is not known at Lambda module creation time.
    # This egress allows port 5432 to any destination within the VPC.
    # The RDS SG ingress rule (defined in rds/security_groups.tf) restricts
    # inbound to this specific SG, achieving the same least-privilege result.
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    description     = "HTTPS to VPC endpoints (preferred path via private DNS)"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.sg_vpce_id]
  }

  egress {
    description = "HTTPS outbound fallback (ECR/AWS via NAT when VPC endpoint DNS not yet active)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-sg-lambda"
  }
}
