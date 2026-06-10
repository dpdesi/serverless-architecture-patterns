provider "aws" {
  region = var.region
}

# The entire subsystem comes from one manifest. Edit subsystem.yaml, not this
# file - the composition derives the hub routes, queue policies, glue IAM and
# observability wiring from it.
module "payouts" {
  source = "../../../modules/composition/subsystem"

  manifest = yamldecode(file("${path.module}/subsystem.yaml"))
}
