locals {
  effective_kms_key_arn = var.create_kms_key ? aws_kms_key.this[0].arn : var.kms_key_arn
  primary_bucket_name   = coalesce(var.primary_origin_bucket_name, "${var.name}-primary")
  default_target_origin = var.secondary_origin == null ? "primary" : "primary-secondary"
  acm_enabled           = var.acm_certificate_arn != null
}

resource "aws_kms_key" "this" {
  count = var.create_kms_key ? 1 : 0

  description         = "KMS key for ${var.name} frontend edge origin bucket"
  enable_key_rotation = true
  tags                = var.tags

  lifecycle {
    precondition {
      condition     = var.create_kms_key || var.kms_key_arn != null
      error_message = "Provide a kms_key_arn when create_kms_key is false."
    }
  }
}

resource "aws_s3_bucket" "primary" {
  bucket = local.primary_bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "primary" {
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      kms_master_key_id = local.effective_kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_cloudfront_origin_access_control" "primary" {
  name                              = "${var.name}-primary-oac"
  description                       = "Restricts access to the ${var.name} primary origin bucket to the CloudFront distribution."
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_response_headers_policy" "this" {
  name    = "${var.name}-security-headers"
  comment = "Default security headers policy for ${var.name}."

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = var.description
  default_root_object = var.default_root_object
  price_class         = var.price_class
  aliases             = var.domain_aliases
  web_acl_id          = var.web_acl_arn
  tags                = var.tags

  origin {
    domain_name              = aws_s3_bucket.primary.bucket_regional_domain_name
    origin_id                = "primary"
    origin_access_control_id = aws_cloudfront_origin_access_control.primary.id
  }

  dynamic "origin" {
    for_each = var.secondary_origin == null ? [] : [var.secondary_origin]

    content {
      domain_name              = origin.value.domain_name
      origin_id                = "secondary"
      origin_access_control_id = origin.value.origin_access_control_id
    }
  }

  dynamic "origin" {
    for_each = var.api_origins

    content {
      domain_name = origin.value.domain_name
      origin_id   = "api-${origin.key}"
      origin_path = origin.value.origin_path

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  dynamic "origin_group" {
    for_each = var.secondary_origin == null ? [] : [var.secondary_origin]

    content {
      origin_id = "primary-secondary"

      failover_criteria {
        status_codes = var.failover_status_codes
      }

      member {
        origin_id = "primary"
      }

      member {
        origin_id = "secondary"
      }
    }
  }

  default_cache_behavior {
    target_origin_id           = local.default_target_origin
    viewer_protocol_policy     = var.viewer_protocol_policy
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id
    compress                   = true
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.api_origins

    content {
      path_pattern               = ordered_cache_behavior.value.path_pattern
      target_origin_id           = "api-${ordered_cache_behavior.key}"
      viewer_protocol_policy     = "https-only"
      allowed_methods            = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods             = ["GET", "HEAD"]
      cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
      origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
      response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id
      compress                   = true
    }
  }

  dynamic "custom_error_response" {
    for_each = var.spa_error_responses ? [403, 404] : []

    content {
      error_code            = custom_error_response.value
      response_code         = 200
      response_page_path    = "/${var.default_root_object}"
      error_caching_min_ttl = 0
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction.type
      locations        = var.geo_restriction.type == "none" ? [] : var.geo_restriction.locations
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = !local.acm_enabled
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = local.acm_enabled ? "sni-only" : null
    minimum_protocol_version       = local.acm_enabled ? var.minimum_protocol_version : "TLSv1"
  }

  dynamic "logging_config" {
    for_each = var.access_log_bucket_domain_name == null ? [] : [var.access_log_bucket_domain_name]

    content {
      bucket          = logging_config.value
      include_cookies = false
      prefix          = coalesce(var.access_log_prefix, "${var.name}/")
    }
  }

  lifecycle {
    precondition {
      condition     = length(var.domain_aliases) == 0 || local.acm_enabled
      error_message = "Provide acm_certificate_arn when domain_aliases is set."
    }
  }
}

data "aws_iam_policy_document" "primary_bucket" {
  statement {
    sid     = "AllowCloudFrontServicePrincipalRead"
    actions = ["s3:GetObject"]
    resources = [
      "${aws_s3_bucket.primary.arn}/*"
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.primary.arn, "${aws_s3_bucket.primary.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "primary" {
  bucket = aws_s3_bucket.primary.id
  policy = data.aws_iam_policy_document.primary_bucket.json
}
