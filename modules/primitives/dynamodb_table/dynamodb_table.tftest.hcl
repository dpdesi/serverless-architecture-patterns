mock_provider "aws" {}

run "valid_table_contract" {
  command = plan

  variables {
    name     = "contract-table"
    hash_key = "pk"
    attributes = [
      {
        name = "pk"
        type = "S"
      }
    ]
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = aws_dynamodb_table.this.billing_mode == "PAY_PER_REQUEST"
    error_message = "DynamoDB tables should default to on-demand billing."
  }
}
