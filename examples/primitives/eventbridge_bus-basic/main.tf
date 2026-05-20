provider "aws" {
  region = "eu-west-2"
}

module "bus" {
  source = "../../../modules/primitives/eventbridge_bus"

  name = "example-customer-dev-bus"
  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

output "bus_name" {
  value = module.bus.name
}
