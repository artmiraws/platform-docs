output "bucket_name" {
  description = "S3 bucket that stores the site content."
  value       = aws_s3_bucket.site.bucket
}

output "distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation)."
  value       = aws_cloudfront_distribution.this.id
}

output "site_url" {
  description = "Public URL of the site."
  value       = "https://${var.site_hostname}"
}
