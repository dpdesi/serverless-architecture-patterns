output "api_id" {
  description = "HTTP API ID."
  value       = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  description = "HTTP API endpoint (full URL including scheme)."
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "api_domain_name" {
  description = "Host-only portion of the HTTP API endpoint (no scheme). Suitable for use as a CloudFront origin domain_name."
  value       = trimprefix(aws_apigatewayv2_api.this.api_endpoint, "https://")
}

output "execution_arn" {
  description = "HTTP API execution ARN."
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "stage_name" {
  description = "Stage name."
  value       = aws_apigatewayv2_stage.this.name
}

output "authorizer_id" {
  description = "JWT authoriser ID when configured."
  value       = try(aws_apigatewayv2_authorizer.jwt[0].id, null)
}
