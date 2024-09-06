locals {
  # Add website s3 bucket name to bucket_names
  bucket_names = concat(var.bucket_names, [var.website_bucket_name])

  # To avoid the website downloads those file instead of rendering/displaying | extension => MIME type
  website_content_types = {
    ".html" : "text/html",
    ".css" : "text/css",
    ".js" : "text/javascript"
    ".png" : "image/png"
  }
}


#########################
####### Buckets #########
#########################

# Create the S3 buckets including website hosting
resource "aws_s3_bucket" "buckets" {
  for_each = { for name in local.bucket_names : name => name }
  bucket   = each.value

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = each.value
    Environment = var.environment
  }
}

# Attach bucket policy to prevent deletion except 'voicecloning-outputs'.
resource "aws_s3_bucket_policy" "prevent_delete" {
  for_each = { for name in var.bucket_names : name => name if name != "voicecloning-outputs" }
  bucket   = each.value

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "s3_bucket_policy_to_prevent_deletion",
    Statement = [
      {
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:DeleteBucket",
        Resource  = aws_s3_bucket.buckets[each.key].arn
      },
      {
        Effect    = "Deny",
        Principal = "*",
        Action    = ["s3:DeleteObject", "s3:DeleteObjectVersion"],
        Resource  = "${aws_s3_bucket.buckets[each.key].arn}/*"
      }
    ],
  })
}


# Attach bucket policy for enabling access to audio files in output bucket from the website.
# TODO: Not secure since it is open.

resource "aws_s3_bucket_public_access_block" "turn_it_off" {
  bucket = aws_s3_bucket.buckets["voicecloning-outputs"].id

  block_public_acls       = false
  ignore_public_acls       = false
  block_public_policy     = false
  restrict_public_buckets = false
}


resource "aws_s3_bucket_policy" "allow_website_to_fetch_audio_files" {
  bucket = aws_s3_bucket.buckets["voicecloning-outputs"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Deny",
        Principal = "*",
        Action    = ["s3:DeleteObject", "s3:DeleteObjectVersion"],
        Resource  = "${aws_s3_bucket.buckets["voicecloning-outputs"].arn}/*"
      },
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.buckets["voicecloning-outputs"].arn}/*"
      },
    ]
  })
}



##################################
######## Website specific ########
##################################

# Policy for static website hosted on s3
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket                  = aws_s3_bucket.buckets[var.website_bucket_name].id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Policy for static website hosted on s3
resource "aws_s3_object" "website_files" {
  bucket   = aws_s3_bucket.buckets[var.website_bucket_name].id
  for_each = fileset(path.module, "${var.website_files_path}/**/*.{html,css,js,png}")
  # Here, replace to avoid having the file path prefix in S3, we just need bucket/file.html structure.
  key          = replace(each.value, "/^${var.website_files_path}/", "")
  source       = each.value
  content_type = lookup(local.website_content_types, regex("\\.[^.]+$", each.value), null)
  etag         = filemd5(each.value)
}

# Allow public access to files in website bucket for hosting
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  depends_on = [aws_s3_bucket_public_access_block.public_access_block]
  bucket     = aws_s3_bucket.buckets[var.website_bucket_name].id
  policy = jsonencode(
    {
      Version : "2012-10-17",
      Statement : [
        {
          Effect    = "Deny",
          Principal = "*",
          Action    = "s3:DeleteBucket",
          Resource  = aws_s3_bucket.buckets[var.website_bucket_name].arn
        },
        {
          Effect    = "Deny",
          Principal = "*",
          Action    = ["s3:DeleteObject", "s3:DeleteObjectVersion"],
          Resource  = "${aws_s3_bucket.buckets[var.website_bucket_name].arn}/*"
        },
        {
          Sid       = "MakeTheFilesPubliclyAvailable",
          Effect    = "Allow",
          Principal = "*",
          Action    = "s3:GetObject",
          Resource  = "${aws_s3_bucket.buckets[var.website_bucket_name].arn}/*"
        }
      ]
    }
  )
}

resource "aws_s3_bucket_website_configuration" "website_hosting" {
  bucket = aws_s3_bucket.buckets[var.website_bucket_name].id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}

