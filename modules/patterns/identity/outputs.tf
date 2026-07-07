output "user_pool_id" {
  description = "Cognito user pool ID."
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  description = "Cognito user pool ARN."
  value       = aws_cognito_user_pool.this.arn
}

output "issuer" {
  description = "OpenID Connect issuer URL for the pool. This is the value JWT authorisers validate tokens against."
  value       = local.issuer
}

output "audience" {
  description = "All client IDs, in a stable order. This is the audience list a JWT authoriser accepts."
  value       = [for key in sort(keys(aws_cognito_user_pool_client.this)) : aws_cognito_user_pool_client.this[key].id]
}

output "jwt_authorizer" {
  description = "Shaped exactly for the bff_service / esg_service / api_http `jwt_authorizer` input: pass this object through unchanged."
  value = {
    issuer   = local.issuer
    audience = [for key in sort(keys(aws_cognito_user_pool_client.this)) : aws_cognito_user_pool_client.this[key].id]
  }
}

output "client_ids" {
  description = "Client IDs keyed by the clients map key."
  value       = { for key, client in aws_cognito_user_pool_client.this : key => client.id }
}

output "hosted_ui_base_url" {
  description = "Base URL of the hosted UI when a domain prefix was configured, else null."
  value = local.hosted_ui_enabled ? (
    "https://${aws_cognito_user_pool_domain.this[0].domain}.auth.${data.aws_region.current.region}.amazoncognito.com"
  ) : null
}
