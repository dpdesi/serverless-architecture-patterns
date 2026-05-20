provider "aws" {
  region = "eu-west-2"
}

module "event_lake" {
  source = "../../../modules/patterns/event_lake"

  name        = "example-customer-event-lake"
  bucket_name = "example-customer-event-lake"
  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

output "delivery_stream_name" {
  value = module.event_lake.delivery_stream_name
}
