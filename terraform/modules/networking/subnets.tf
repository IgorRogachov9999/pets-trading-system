# ==============================================================================
# modules/networking/subnets.tf
# Public, private-app, and private-db subnets across AZs
# ==============================================================================

locals {
  # Fixed CIDR map — public 10.0.[1,2].0/24, app 10.0.[11,12].0/24, db 10.0.[21,22].0/24
  public_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  app_cidrs    = ["10.0.11.0/24", "10.0.12.0/24"]
  db_cidrs     = ["10.0.21.0/24", "10.0.22.0/24"]
}

# ------------------------------------------------------------------------------
# Public Subnets (ALB, NAT GW)
# ------------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = var.az_names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-subnet-public-${count.index + 1}"
    Tier = "public"
  }
}

# ------------------------------------------------------------------------------
# Private App Subnets (ECS Fargate tasks, Lambda)
# ------------------------------------------------------------------------------
resource "aws_subnet" "private_app" {
  count = var.az_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.app_cidrs[count.index]
  availability_zone = var.az_names[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-subnet-app-${count.index + 1}"
    Tier = "private-app"
  }
}

# ------------------------------------------------------------------------------
# Private DB Subnets (RDS)
# RDS subnet group requires >= 2 subnets even in dev; always create 2.
# ------------------------------------------------------------------------------
resource "aws_subnet" "private_db" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.db_cidrs[count.index]
  availability_zone = var.az_names[count.index % var.az_count]

  tags = {
    Name = "${var.project_name}-${var.environment}-subnet-db-${count.index + 1}"
    Tier = "private-db"
  }
}
