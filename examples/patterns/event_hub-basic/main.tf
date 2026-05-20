provider "aws" {
  region = "eu-west-2"
}

module "event_hub" {
  source = "../../../modules/patterns/event_hub"

  name = "example-customer-dev-hub"
  routes = {
    customer_events = {
      event_pattern = jsonencode({
        source = ["customer.bff"]
      })
      targets = []
    }
  }
  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

output "bus_name" {
  value = module.event_hub.bus_name
}
