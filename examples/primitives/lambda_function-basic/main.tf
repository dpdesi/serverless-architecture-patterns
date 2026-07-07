provider "aws" {
  region = "eu-west-2"
}

data "archive_file" "handler" {
  type        = "zip"
  source_file = "${path.module}/index.js"
  output_path = "${path.module}/handler.zip"
}

resource "aws_kms_key" "artefacts" {
  description         = "KMS key for the example artefact bucket"
  enable_key_rotation = true
  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

resource "aws_s3_bucket" "artefacts" {
  bucket_prefix = "sap-lambda-artefacts-"
  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

resource "aws_s3_bucket_public_access_block" "artefacts" {
  bucket                  = aws_s3_bucket.artefacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artefacts" {
  bucket = aws_s3_bucket.artefacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.artefacts.arn
    }
  }
}

resource "aws_s3_object" "handler" {
  bucket = aws_s3_bucket.artefacts.bucket
  key    = "handler.zip"
  source = data.archive_file.handler.output_path
  etag   = data.archive_file.handler.output_md5
}

module "handler" {
  source = "../../../modules/primitives/lambda_function"

  name      = "example-lambda-handler"
  s3_bucket = aws_s3_bucket.artefacts.bucket
  s3_key    = aws_s3_object.handler.key
  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

output "function_name" {
  value = module.handler.function_name
}
