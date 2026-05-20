provider "aws" {
  region = "eu-west-2"
}

module "observability" {
  source = "../../../modules/patterns/observability_baseline"

  name = "example-customer-observability"
  lambda_functions = {
    rest = {
      function_name   = "example-customer-bff-rest"
      timeout_seconds = 10
      dlq_queue_name  = "example-customer-bff-rest-dlq"
    }
  }
  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

output "alarm_topic_arn" {
  value = module.observability.alarm_topic_arn
}
