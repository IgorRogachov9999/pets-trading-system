output "builds_bucket_name" {
  description = "S3 bucket name for CI/CD build artifact storage (shared across environments)."
  value       = aws_s3_bucket.builds.bucket
}

output "builds_bucket_arn" {
  description = "S3 bucket ARN for IAM policy references."
  value       = aws_s3_bucket.builds.arn
}
