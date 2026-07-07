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
  bucket_prefix = "sap-bff-artefacts-"
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

resource "aws_s3_object" "rest" {
  bucket = aws_s3_bucket.artefacts.bucket
  key    = "rest.zip"
  source = data.archive_file.handler.output_path
  etag   = data.archive_file.handler.output_md5
}

resource "aws_s3_object" "listener" {
  bucket = aws_s3_bucket.artefacts.bucket
  key    = "listener.zip"
  source = data.archive_file.handler.output_path
  etag   = data.archive_file.handler.output_md5
}

resource "aws_s3_object" "trigger" {
  bucket = aws_s3_bucket.artefacts.bucket
  key    = "trigger.zip"
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

module "bff" {
  source = "../../../modules/patterns/bff_service"

  name           = "example-customer-bff"
  event_bus_name = module.event_hub.bus_name
  event_bus_arn  = module.event_hub.bus_arn
  artefacts = {
    rest = {
      s3_bucket = aws_s3_bucket.artefacts.bucket
      s3_key    = aws_s3_object.rest.key
    }
    listener = {
      s3_bucket = aws_s3_bucket.artefacts.bucket
      s3_key    = aws_s3_object.listener.key
    }
    trigger = {
      s3_bucket = aws_s3_bucket.artefacts.bucket
      s3_key    = aws_s3_object.trigger.key
    }
  }
  table = {
    name = "example-customer"
  }
  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

output "api_endpoint" {
  value = module.bff.api_endpoint
}
