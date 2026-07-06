# ── CloudFront Distribution ───────────────────────────────────────────────────
# Two origins:
#   1. S3 — for all frontend static files (/* paths)
#   2. API Gateway — for all backend requests (/api/* paths)

locals {
  s3_origin_id  = "S3-frontend"
  api_origin_id = "APIGW-backend"
}

# CloudFront Function: rewrite /path/ → /path/index.html for Next.js static export
resource "aws_cloudfront_function" "rewrite_index" {
  name    = "${var.app_name}-${var.environment}-rewrite-index"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<-EOF
    function handler(event) {
      var uri = event.request.uri;
      if (uri.endsWith('/')) {
        event.request.uri += 'index.html';
      } else if (!uri.split('/').pop().includes('.')) {
        event.request.uri += '/index.html';
      }
      return event.request;
    }
  EOF
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_200" # US, Europe, Asia (keeps costs reasonable for India)
  wait_for_deployment = false

  comment = "${var.app_name} ${var.environment} frontend"

  aliases = var.domain_name != "" ? [var.domain_name, "www.${var.domain_name}"] : []

  # ── Origin 1: S3 (frontend static files) ──────────────────────────────────

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # ── Origin 2: API Gateway (Go backend) ────────────────────────────────────

  origin {
    domain_name = replace(aws_apigatewayv2_api.backend.api_endpoint, "https://", "")
    origin_id   = local.api_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # ── Cache behaviors ────────────────────────────────────────────────────────

  # /api/* → API Gateway — no caching, forward all headers/query strings
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    target_origin_id = local.api_origin_id
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    compress         = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type", "Origin"]
      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # Default behavior: S3 — cache static assets aggressively
  default_cache_behavior {
    target_origin_id       = local.s3_origin_id
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.rewrite_index.arn
    }

    min_ttl     = 0
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # ── SPA fallback: 403/404 from S3 → index.html (client-side routing) ──────
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  # ── TLS ───────────────────────────────────────────────────────────────────

  dynamic "viewer_certificate" {
    for_each = var.domain_name != "" ? [1] : []
    content {
      acm_certificate_arn      = aws_acm_certificate_validation.frontend[0].certificate_arn
      ssl_support_method       = "sni-only"
      minimum_protocol_version = "TLSv1.2_2021"
    }
  }

  dynamic "viewer_certificate" {
    for_each = var.domain_name == "" ? [1] : []
    content {
      cloudfront_default_certificate = true
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

# ── ACM Certificate (only if custom domain is set) ────────────────────────────
# Must be in us-east-1 for CloudFront — uses the aliased provider.

resource "aws_acm_certificate" "frontend" {
  count             = var.domain_name != "" ? 1 : 0
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Placeholder: add the CNAME records output by Terraform to your DNS provider.
output "acm_validation_records" {
  description = "Add these CNAME records to your DNS to validate the ACM certificate"
  value = var.domain_name != "" ? {
    for dvo in aws_acm_certificate.frontend[0].domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  } : {}
}

resource "aws_acm_certificate_validation" "frontend" {
  count           = var.domain_name != "" ? 1 : 0
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.frontend[0].arn
  # validation_record_fqdns must be added manually to DNS first.
  # Terraform will wait until validation succeeds.
}

output "cloudfront_domain" {
  description = "CloudFront domain — point your domain's CNAME here"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID — used in deploy script to invalidate cache"
  value       = aws_cloudfront_distribution.frontend.id
}
