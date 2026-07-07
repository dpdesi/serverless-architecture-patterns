data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  effective_kms_key_arn = var.create_kms_key ? aws_kms_key.this[0].arn : var.kms_key_arn
  bucket_name           = coalesce(var.bucket_name, var.name)
  oidc_enabled          = var.github_oidc != null

  oidc_provider_arn = local.oidc_enabled ? coalesce(
    var.github_oidc.provider_arn,
    "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com",
  ) : null

  oidc_subjects = local.oidc_enabled ? coalesce(
    var.github_oidc.subjects,
    ["repo:${var.github_oidc.repository}:*"],
  ) : []
}

resource "aws_kms_key" "this" {
  count = var.create_kms_key ? 1 : 0

  description         = "KMS key for ${var.name} artefact bucket"
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

# Versioning is the rollback mechanism: Lambda fetches the zip at apply time,
# so keeping superseded versions means a bad artefact can be reverted by
# republishing the previous object version.
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

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-superseded-artefacts"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]

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

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket.json

  depends_on = [aws_s3_bucket_public_access_block.this]
}

# --- Optional GitHub Actions publisher role -----------------------------------

data "aws_iam_policy_document" "github_assume" {
  count = local.oidc_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.oidc_subjects
    }
  }
}

resource "aws_iam_role" "publisher" {
  count = local.oidc_enabled ? 1 : 0

  name               = coalesce(var.github_oidc.role_name, "${var.name}-publisher")
  assume_role_policy = data.aws_iam_policy_document.github_assume[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "publisher" {
  count = local.oidc_enabled ? 1 : 0

  statement {
    sid = "PublishArtefacts"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:AbortMultipartUpload",
    ]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }

  statement {
    sid = "InspectBucket"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [aws_s3_bucket.this.arn]
  }

  statement {
    sid = "UseArtefactKey"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [local.effective_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "publisher" {
  count = local.oidc_enabled ? 1 : 0

  name   = "${var.name}-publisher"
  role   = aws_iam_role.publisher[0].id
  policy = data.aws_iam_policy_document.publisher[0].json
}
