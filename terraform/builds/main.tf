# ==============================================================================
# builds/main.tf
# Standalone builds artifact bucket — shared across all environments.
# Build artifacts uploaded by CI/CD are stored here, then deployed to the
# per-environment frontend S3 bucket. This configuration has its own state:
#   pts/builds/terraform.tfstate
# Run this BEFORE the per-environment Terraform in CI/CD pipelines.
# ==============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      Terraform = "true"
    }
  }
}

resource "aws_s3_bucket" "builds" {
  bucket = "${var.project_name}-builds"

  tags = {
    Name = "${var.project_name}-s3-builds"
  }
}

resource "aws_s3_bucket_versioning" "builds" {
  bucket = aws_s3_bucket.builds.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "builds" {
  bucket                  = aws_s3_bucket.builds.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "builds" {
  bucket = aws_s3_bucket.builds.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "builds" {
  bucket = aws_s3_bucket.builds.id

  rule {
    id     = "expire-old-artifacts"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
