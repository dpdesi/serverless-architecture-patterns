provider "aws" {
  region = "eu-west-2"
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

module "control" {
  source = "../../../modules/patterns/control_service"

  name           = "example-customer-control"
  mode           = "step_functions"
  event_bus_name = module.event_hub.bus_name
  event_bus_arn  = module.event_hub.bus_arn
  event_pattern = jsonencode({
    source = ["customer.bff"]
  })
  state_machine_definition = jsonencode({
    Comment = "Example Control Service workflow"
    StartAt = "Accepted"
    States = {
      Accepted = {
        Type = "Succeed"
      }
    }
  })
  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

output "state_machine_arn" {
  value = module.control.state_machine_arn
}
