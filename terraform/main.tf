# ==============================================================================
# main.tf — Provider configuration and module orchestration
# pets-trading-system
# ==============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Terraform   = "true"
      ManagedBy   = "terraform"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Slice AZ names to the requested count (e.g. ["us-east-1a"] or ["us-east-1a","us-east-1b"])
  az_names = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  # Extract single-letter suffixes for subnet CIDR construction
  az_suffixes = [for az in local.az_names : substr(az, length(az) - 1, 1)]
}

# ------------------------------------------------------------------------------
# Networking — VPC, subnets, IGW, NAT GW, route tables, VPCE SG, VPC endpoints
# Service SGs (ALB, ECS, Lambda, RDS) are defined in their respective modules.
# ------------------------------------------------------------------------------
module "networking" {
  source = "./modules/networking"

  aws_region   = var.aws_region
  project_name = var.project_name
  environment  = var.environment
  az_count     = var.az_count
  az_names     = local.az_names
}

# ------------------------------------------------------------------------------
# ECR — Data sources referencing the shared ECR repositories.
# ECR is managed by terraform/ecr/ (its own state: pts/ecr/terraform.tfstate).
# Run terraform/ecr/ BEFORE this configuration in CI/CD pipelines.
# ------------------------------------------------------------------------------
data "aws_ecr_repository" "trading_api" {
  name = "${var.project_name}-trading-api"
}

data "aws_ecr_repository" "lifecycle_lambda" {
  name = "${var.project_name}-lifecycle-lambda"
}

# ------------------------------------------------------------------------------
# S3 + CloudFront — Frontend SPA hosting
# ------------------------------------------------------------------------------
module "s3_cloudfront" {
  source = "./modules/s3-cloudfront"

  project_name = var.project_name
  environment  = var.environment
}

# ------------------------------------------------------------------------------
# Cognito — User Pool for trader authentication
# ------------------------------------------------------------------------------
module "cognito" {
  source = "./modules/cognito"

  project_name = var.project_name
  environment  = var.environment
}

# ------------------------------------------------------------------------------
# DynamoDB — WebSocket connection tracking table
# ------------------------------------------------------------------------------
module "dynamodb" {
  source = "./modules/dynamodb"

  project_name = var.project_name
  environment  = var.environment
}

# ------------------------------------------------------------------------------
# Secrets Manager — DB connection string and app config placeholders
# ------------------------------------------------------------------------------
module "secrets" {
  source = "./modules/secrets"

  project_name = var.project_name
  environment  = var.environment
}

# ------------------------------------------------------------------------------
# RDS — PostgreSQL 16 database
# ------------------------------------------------------------------------------
module "rds" {
  source = "./modules/rds"

  project_name      = var.project_name
  environment       = var.environment
  az_count          = var.az_count
  vpc_id            = module.networking.vpc_id
  db_subnet_ids     = module.networking.private_db_subnet_ids
  ecs_sg_id         = module.ecs.sg_ecs_id
  lambda_sg_id      = module.lambda.sg_lambda_id
  db_instance_class = var.db_instance_class
  multi_az          = var.az_count > 1
}

# ------------------------------------------------------------------------------
# ECS — Fargate cluster, Trading API service, ALB
# IAM roles (task execution + task) are owned by the ECS module.
# ------------------------------------------------------------------------------
module "ecs" {
  source = "./modules/ecs"

  project_name           = var.project_name
  environment            = var.environment
  aws_region             = var.aws_region
  vpc_id                 = module.networking.vpc_id
  vpc_cidr_block         = module.networking.vpc_cidr_block
  public_subnet_ids      = module.networking.public_subnet_ids
  private_app_subnet_ids = module.networking.private_app_subnet_ids
  sg_vpce_id             = module.networking.sg_vpce_id
  trading_api_image_url  = data.aws_ecr_repository.trading_api.repository_url
  desired_count          = var.az_count > 1 ? 2 : 1
  ecs_cpu                = var.ecs_cpu
  ecs_memory             = var.ecs_memory
  log_retention_days     = var.log_retention_days
  dynamodb_table_name    = module.dynamodb.table_name
}

# ------------------------------------------------------------------------------
# Lambda — Lifecycle Engine (EventBridge Scheduler, every 60s)
# IAM execution role is owned by the Lambda module.
# ------------------------------------------------------------------------------
module "lambda" {
  source = "./modules/lambda"

  project_name               = var.project_name
  environment                = var.environment
  vpc_id                     = module.networking.vpc_id
  vpc_cidr_block             = module.networking.vpc_cidr_block
  private_app_subnet_ids     = module.networking.private_app_subnet_ids
  sg_vpce_id                 = module.networking.sg_vpce_id
  lifecycle_lambda_image_url = data.aws_ecr_repository.lifecycle_lambda.repository_url
  db_endpoint                = module.rds.db_endpoint
  db_name                    = module.rds.db_name
  log_retention_days         = var.log_retention_days
}

# ------------------------------------------------------------------------------
# API Gateway — REST API (VPC Link → ALB) + WebSocket API + WAF
# ------------------------------------------------------------------------------
module "api_gateway" {
  source = "./modules/api-gateway"

  project_name          = var.project_name
  environment           = var.environment
  alb_arn               = module.ecs.alb_arn
  alb_dns_name          = module.ecs.alb_dns_name
  cognito_user_pool_arn = module.cognito.user_pool_arn
}
