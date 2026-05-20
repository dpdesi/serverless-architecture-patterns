provider "aws" {
  region                      = "eu-west-2"
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    apigatewayv2 = var.localstack_endpoint
    cloudwatch   = var.localstack_endpoint
    dynamodb     = var.localstack_endpoint
    events       = var.localstack_endpoint
    iam          = var.localstack_endpoint
    kms          = var.localstack_endpoint
    lambda       = var.localstack_endpoint
    logs         = var.localstack_endpoint
    s3           = var.localstack_endpoint
    sqs          = var.localstack_endpoint
    sts          = var.localstack_endpoint
  }
}

provider "aws" {
  alias                       = "secondary"
  region                      = "eu-west-1"
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    apigatewayv2 = var.localstack_endpoint
    cloudwatch   = var.localstack_endpoint
    dynamodb     = var.localstack_endpoint
    events       = var.localstack_endpoint
    iam          = var.localstack_endpoint
    kms          = var.localstack_endpoint
    lambda       = var.localstack_endpoint
    logs         = var.localstack_endpoint
    s3           = var.localstack_endpoint
    sqs          = var.localstack_endpoint
    sts          = var.localstack_endpoint
  }
}

data "archive_file" "handler" {
  type        = "zip"
  source_file = "${path.module}/src/index.js"
  output_path = "${path.module}/handler.zip"
}

resource "aws_s3_bucket" "artefacts" {
  bucket = "customer-subsystem-artefacts"
  tags = {
    Environment = "dev"
    System      = "customer"
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
      sse_algorithm = "AES256"
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

locals {
  tags = {
    Environment = "dev"
    System      = "customer"
    Subsystem   = "customer"
    Owner       = "platform"
  }
}

module "event_hub" {
  source = "../../../modules/patterns/event_hub"

  name = "customer-customer-dev-hub"
  routes = {
    customer_events = {
      event_pattern = jsonencode({
        source = ["customer.bff"]
      })
      targets = []
    }
  }
  tags = local.tags
}

module "customer_bff" {
  source = "../../../modules/patterns/bff_service"

  name           = "customer-customer-dev-customer-bff"
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
    name = "customer-customer-dev-customer"
  }
  tags = local.tags
}
