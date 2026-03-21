# ==============================================================================
# iam.tf — Cross-cutting IAM data sources
# pets-trading-system
#
# NOTE: The GitHub Actions OIDC provider and IAM role (pts-github-actions) are
# managed MANUALLY outside Terraform to avoid the bootstrap catch-22.
# Role ARN: arn:aws:iam::878257311738:role/pts-github-actions
# The role ARN is stored in GitHub Secret AWS_ROLE_ARN and consumed by all
# GitHub Actions workflows — no Terraform output needed.
# ==============================================================================

data "aws_caller_identity" "root" {}
data "aws_region" "root" {}
