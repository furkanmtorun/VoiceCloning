output "website_https_url" {
  description = "Website URL (HTTPS)"
  value       = aws_cloudfront_distribution.website_distribution.domain_name
}

output "api_url" {
  description = "URL for the API living in Lambda connected to API Gateway."
  value       = aws_cloudfront_distribution.api_gateway.domain_name
}