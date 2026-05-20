provider "aws" {
  region = "eu-west-2"
}

module "table" {
  source = "../../../modules/primitives/dynamodb_table"

  name      = "example-customer-dev"
  hash_key  = "pk"
  range_key = "sk"
  attributes = [
    {
      name = "pk"
      type = "S"
    },
    {
      name = "sk"
      type = "S"
    }
  ]
  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

output "table_name" {
  value = module.table.name
}
