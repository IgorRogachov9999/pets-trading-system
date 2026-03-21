output "s3_bucket_name" {
  description = "S3 bucket name for frontend asset deployment."
  value       = aws_s3_bucket.frontend.bucket
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID — required for cache invalidation in CI/CD."
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name for the frontend SPA."
  value       = aws_cloudfront_distribution.frontend.domain_name
}

