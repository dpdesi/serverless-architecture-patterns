provider "aws" {
  region = "eu-west-2"
}

data "archive_file" "handler" {
  type        = "zip"
  source_file = "${path.module}/src/index.js"
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
  bucket_prefix = "sap-esg-artefacts-"
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

resource "aws_s3_object" "ingress" {
  bucket = aws_s3_bucket.artefacts.bucket
  key    = "ingress.zip"
  source = data.archive_file.handler.output_path
  etag   = data.archive_file.handler.output_md5
}

resource "aws_s3_object" "egress" {
  bucket = aws_s3_bucket.artefacts.bucket
  key    = "egress.zip"
  source = data.archive_file.handler.output_path
  etag   = data.archive_file.handler.output_md5
}

module "event_hub" {
  source = "../../../modules/patterns/event_hub"

  name = "example-customer-dev-hub"
  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

module "esg" {
  source = "../../../modules/patterns/esg_service"

  name           = "example-customer-payments-esg"
  event_bus_name = module.event_hub.bus_name
  event_bus_arn  = module.event_hub.bus_arn
  external_event_pattern = jsonencode({
    source = ["customer.bff"]
  })
  artefacts = {
    ingress = {
      s3_bucket = aws_s3_bucket.artefacts.bucket
      s3_key    = aws_s3_object.ingress.key
    }
    egress = {
      s3_bucket = aws_s3_bucket.artefacts.bucket
      s3_key    = aws_s3_object.egress.key
    }
  }
  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

output "webhook_api_endpoint" {
  value = module.esg.webhook_api_endpoint
}
