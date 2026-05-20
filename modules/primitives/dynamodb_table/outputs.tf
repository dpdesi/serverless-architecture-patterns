output "name" {
  description = "DynamoDB table name."
  value       = aws_dynamodb_table.this.name
}

output "arn" {
  description = "DynamoDB table ARN."
  value       = aws_dynamodb_table.this.arn
}

output "stream_arn" {
  description = "DynamoDB stream ARN when enabled."
  value       = aws_dynamodb_table.this.stream_arn
}
