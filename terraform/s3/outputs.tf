# S3 Bucket names
output "bucket_names" {
  value = var.bucket_names
}

output "website_bucket_name" {
  value = var.website_bucket_name
}

output "website_s3_endpoint" {
  description = "S3 hosting URL (HTTP)"
  value       = aws_s3_bucket_website_configuration.website_hosting.website_endpoint
}


output "website_regional_domain_name" {
  description = "Bucket regional domain name for origin_id in CloudFront"
  value       = aws_s3_bucket.buckets[var.website_bucket_name].bucket_regional_domain_name
}