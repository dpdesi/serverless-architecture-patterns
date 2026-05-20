locals {
  effective_kms_key_arn = var.create_kms_key ? aws_kms_key.this[0].arn : var.kms_key_arn
  bucket_name           = var.name
  invalidation_enabled  = var.frontend_edge_distribution_id != null
}

resource "aws_kms_key" "this" {
  count = var.create_kms_key ? 1 : 0

  description         = "KMS key for ${var.name} micro-frontend artefacts"
  enable_key_rotation = true
  tags                = var.tags

  lifecycle {
    precondition {
      condition     = var.create_kms_key || var.kms_key_arn != null
      error_message = "Provide a kms_key_arn when create_kms_key is false."
    }
  }
}

resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      kms_master_key_id = local.effective_kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

module "deployer" {
  source = "../../primitives/lambda_function"

  name           = "${var.name}-deployer"
  s3_bucket      = var.deployer_artefact.s3_bucket
  s3_key         = var.deployer_artefact.s3_key
  runtime        = var.runtime
  handler        = var.handler
  memory_size    = var.memory_size
  timeout        = var.timeout
  create_kms_key = false
  kms_key_arn    = local.effective_kms_key_arn

  environment_variables = merge(var.environment_variables, {
    BUCKET_NAME      = aws_s3_bucket.this.id
    MANIFESTS_PREFIX = var.manifests_prefix
    MASTER_PREFIX    = var.master_prefix
    DISTRIBUTION_ID  = var.frontend_edge_distribution_id == null ? "" : var.frontend_edge_distribution_id
  })

  policy_statements = concat(
    [
      {
        actions   = ["s3:GetObject", "s3:ListBucket"]
        resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]
      },
      {
        actions   = ["s3:PutObject"]
        resources = ["${aws_s3_bucket.this.arn}/${var.master_prefix}*"]
      }
    ],
    local.invalidation_enabled ? [
      {
        actions   = ["cloudfront:CreateInvalidation"]
        resources = [var.frontend_edge_distribution_arn]
      }
    ] : []
  )

  log_retention_days = var.log_retention_days
  tags               = var.tags
}

resource "terraform_data" "validate_invalidation_inputs" {
  lifecycle {
    precondition {
      condition     = var.frontend_edge_distribution_id == null || var.frontend_edge_distribution_arn != null
      error_message = "Pass frontend_edge_distribution_arn alongside frontend_edge_distribution_id so the deployer Lambda can scope CreateInvalidation."
    }
  }
}

resource "aws_lambda_permission" "s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = module.deployer.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.this.arn
}

resource "aws_s3_bucket_notification" "this" {
  bucket = aws_s3_bucket.this.id

  lambda_function {
    lambda_function_arn = module.deployer.function_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.manifests_prefix
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.s3]
}
