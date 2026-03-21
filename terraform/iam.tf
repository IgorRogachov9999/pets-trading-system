# ==============================================================================
# iam.tf — Cross-cutting data sources used by other modules
# ==============================================================================
#
# NOTE: The GitHub Actions OIDC provider and IAM role (pts-github-actions) are
# managed MANUALLY outside Terraform to avoid the bootstrap catch-22.
# Role ARN: arn:aws:iam::878257311738:role/pts-github-actions
# Set this as the AWS_ROLE_ARN GitHub secret.
# ==============================================================================

data "aws_caller_identity" "root" {}
data "aws_region" "root" {}
