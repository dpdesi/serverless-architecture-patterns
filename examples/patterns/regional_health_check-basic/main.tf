provider "aws" {
  # Route 53 health checks are global but must be declared against us-east-1.
  region = "us-east-1"
}

module "regional_health_check" {
  source = "../../../modules/patterns/regional_health_check"

  name   = "example-regional-health"
  region = "eu-west-2"

  metric_alarms = {
    bff_api_5xx = {
      namespace   = "AWS/ApiGateway"
      metric_name = "5XXError"
      dimensions  = { ApiName = "example-bff-api" }
    }
    bff_table_system_errors = {
      namespace   = "AWS/DynamoDB"
      metric_name = "SystemErrors"
      dimensions  = { TableName = "example-bff-table" }
    }
  }

  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

output "regional_health_check_id" {
  value = module.regional_health_check.regional_health_check_id
}
