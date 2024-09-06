# We use CloudFront to:
# - to enable httpS and SSL protocols (S3 hosting can only utilize HTTP protocol)
# - distribute the website by caching and hosting on edge locations
# - to enhance the performance, security and availability of the API via APIGW.

data "terraform_remote_state" "s3" {
  backend = "s3"
  config = {
    bucket = "fmt-project-tf-backend"
    key    = "terraform_s3.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "api_gateway" {
  backend = "s3"
  config = {
    bucket = "fmt-project-tf-backend"
    key    = "terraform_api_gateway.tfstate"
    region = var.region
  }
}

###########################
######### Website #########
###########################

resource "aws_cloudfront_distribution" "website_distribution" {
  comment         = "CloudFront Distribution for S3 hosted website"
  enabled         = true
  is_ipv6_enabled = true

  origin {
    domain_name = data.terraform_remote_state.s3.outputs.website_s3_endpoint
    origin_id   = data.terraform_remote_state.s3.outputs.website_regional_domain_name

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_keepalive_timeout = 5
      origin_protocol_policy   = "http-only"
      origin_read_timeout      = 30
      origin_ssl_protocols = [
        "TLSv1.2",
      ]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  default_cache_behavior {
    # the ID is for 'CachingOptimized' policy | https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = data.terraform_remote_state.s3.outputs.website_regional_domain_name
  }
}


#########################
########## API ##########
#########################

# CloudFront Dist for Rest API app on lambda via API Gateway: https://advancedweb.hu/how-to-use-api-gateway-with-cloudfront/
resource "aws_cloudfront_distribution" "api_gateway" {
  origin {
    /* 
      We only need the domain name, hence we need to replace
      FROM "https://<id>.some_other.<region>.aws.com/api"
      TO "<id>.some_other.<region>.aws.com"
    */
    domain_name = replace(data.terraform_remote_state.api_gateway.outputs.invoke_url, "/^https?://([^/]*).*/", "$1")
    origin_id   = "api_gateway"
    origin_path = "/api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront Distribution for API Gateway"
  default_root_object = ""

  # aliases = [] # Custom domains can be defined here.

  # FIX: 'The S3 bucket that you specified for CloudFront logs does not enable ACL access'
  # logging_config {
  #   include_cookies = false
  #   bucket          = "voicecloning-logs.s3.amazonaws.com"
  #   prefix          = "cloudfront-api"
  # }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "api_gateway"

    forwarded_values {
      query_string = true
      headers      = ["Origin"] # CORS handling

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  viewer_certificate {
    cloudfront_default_certificate = true # Change this if you are using an ACM certificate.
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}