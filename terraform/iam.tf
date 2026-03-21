# ==============================================================================
# iam.tf — Cross-cutting CI/CD IAM resources (root level)
# GitHub Actions OIDC provider + role — enables keyless CI/CD deployments.
# No static AWS credentials stored in GitHub Secrets.
# ==============================================================================

data "aws_caller_identity" "root" {}
data "aws_region" "root" {}

# ------------------------------------------------------------------------------
# GitHub Actions OIDC Provider
# ------------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint (stable — matches the certificate chain for
  # token.actions.githubusercontent.com as of the provider version).
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name = "${var.project_name}-oidc-github"
  }
}

# ------------------------------------------------------------------------------
# GitHub Actions IAM Role
# ------------------------------------------------------------------------------
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-${var.environment}-role-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-role-github-actions"
  }
}

resource "aws_iam_role_policy" "github_actions_cicd" {
  name = "cicd-permissions"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*" # GetAuthorizationToken is account-level, not resource-level
      },
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        # ECR repos are shared across environments — no environment suffix in repo names.
        Resource = [
          "arn:aws:ecr:${data.aws_region.root.name}:${data.aws_caller_identity.root.account_id}:repository/${var.project_name}-trading-api",
          "arn:aws:ecr:${data.aws_region.root.name}:${data.aws_caller_identity.root.account_id}:repository/${var.project_name}-lifecycle-lambda"
        ]
      },
      {
        Sid    = "ECSDeployTradingAPI"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition"
        ]
        Resource = "*" # ECS service ARN not known at role creation time
      },
      {
        Sid    = "LambdaDeployLifecycle"
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction",
          "lambda:PublishVersion"
        ]
        Resource = "arn:aws:lambda:${data.aws_region.root.name}:${data.aws_caller_identity.root.account_id}:function:${var.project_name}-${var.environment}-lifecycle-lambda"
      },
      {
        Sid    = "S3FrontendDeploy"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-frontend-*",
          "arn:aws:s3:::${var.project_name}-frontend-*/*",
          # Shared builds bucket — no environment suffix (build once, deploy anywhere)
          "arn:aws:s3:::${var.project_name}-builds",
          "arn:aws:s3:::${var.project_name}-builds/*"
        ]
      },
      {
        Sid    = "CloudFrontInvalidation"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:ListDistributions" # Required for runtime auto-discovery of distribution ID
        ]
        Resource = "*" # Distribution ID not known at role creation time
      },
      {
        Sid    = "IAMPassRole"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          module.ecs.ecs_task_execution_role_arn,
          module.ecs.ecs_task_role_arn,
          "arn:aws:iam::${data.aws_caller_identity.root.account_id}:role/${var.project_name}-${var.environment}-role-scheduler"
        ]
      },
      {
        # Broad Terraform apply permissions for infrastructure bootstrap via CI/CD.
        # These permissions allow terraform apply to create all project resources.
        # Narrow or remove this statement once initial bootstrap is complete.
        Sid    = "TerraformApply"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "application-autoscaling:*",
          "ecs:*",
          "ecr:*",
          "rds:*",
          "lambda:*",
          "s3:*",
          "cloudfront:*",
          "cognito-idp:*",
          "dynamodb:*",
          "apigateway:*",
          "wafv2:*",
          "logs:*",
          "secretsmanager:*",
          "events:*",
          "scheduler:*",
          "iam:GetRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:PutRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:AddClientIDToOpenIDConnectProvider",
          "iam:RemoveClientIDFromOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "route53:*",
          "acm:*",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })
}

