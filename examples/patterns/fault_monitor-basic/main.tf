provider "aws" {
  region = "eu-west-2"
}

module "event_hub" {
  source = "../../../modules/patterns/event_hub"

  name = "example-fault-hub"
  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

module "fault_monitor" {
  source = "../../../modules/patterns/fault_monitor"

  name           = "example-fault-monitor"
  event_bus_name = module.event_hub.bus_name
  event_bus_arn  = module.event_hub.bus_arn

  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

output "fault_bucket_name" {
  value = module.fault_monitor.bucket_name
}

output "fault_topic_arn" {
  value = module.fault_monitor.fault_topic_arn
}
