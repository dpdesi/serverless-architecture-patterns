locals {
  default_authorisation_type = var.jwt_authorizer == null ? "NONE" : "JWT"
  effective_kms_key_arn      = var.create_kms_key ? aws_kms_key.this[0].arn : var.kms_key_arn

  route_permissions = {
    for key, route in var.routes : key => {
      method = split(" ", route.route_key)[0] == "ANY" ? "*" : split(" ", route.route_key)[0]
      path   = replace(split(" ", route.route_key)[1], "/\\{[^}]+\\}/", "*")
    }
  }
}

resource "aws_kms_key" "this" {
  count = var.create_kms_key ? 1 : 0

  description         = "KMS key for ${var.name} API logs"
  enable_key_rotation = true
  tags                = var.tags

  lifecycle {
    precondition {
      condition     = var.create_kms_key || var.kms_key_arn != null
      error_message = "Provide a kms_key_arn when create_kms_key is false."
    }
  }
}

resource "aws_apigatewayv2_api" "this" {
  name          = var.name
  description   = var.description
  protocol_type = "HTTP"
  tags          = var.tags

  dynamic "cors_configuration" {
    for_each = var.cors == null ? [] : [var.cors]

    content {
      allow_credentials = cors_configuration.value.allow_credentials
      allow_headers     = cors_configuration.value.allow_headers
      allow_methods     = cors_configuration.value.allow_methods
      allow_origins     = cors_configuration.value.allow_origins
      expose_headers    = cors_configuration.value.expose_headers
      max_age           = cors_configuration.value.max_age
    }
  }
}

resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${var.name}"
  retention_in_days = var.access_log_retention_days
  kms_key_id        = local.effective_kms_key_arn
  tags              = var.tags
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  count = var.jwt_authorizer == null ? 0 : 1

  api_id           = aws_apigatewayv2_api.this.id
  authorizer_type  = "JWT"
  identity_sources = var.jwt_authorizer.identity_sources
  name             = var.jwt_authorizer.name

  jwt_configuration {
    audience = var.jwt_authorizer.audience
    issuer   = var.jwt_authorizer.issuer
  }
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.stage_name
  auto_deploy = var.auto_deploy
  tags        = var.tags

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      integrationError = "$context.integrationErrorMessage"
      responseLength   = "$context.responseLength"
    })
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  for_each = var.routes

  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = each.value.lambda_function_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
}

resource "aws_apigatewayv2_route" "lambda" {
  for_each = var.routes

  api_id               = aws_apigatewayv2_api.this.id
  route_key            = each.value.route_key
  target               = "integrations/${aws_apigatewayv2_integration.lambda[each.key].id}"
  authorization_type   = coalesce(each.value.authorisation_type, local.default_authorisation_type)
  authorizer_id        = coalesce(each.value.authorisation_type, local.default_authorisation_type) == "JWT" ? aws_apigatewayv2_authorizer.jwt[0].id : null
  authorization_scopes = coalesce(each.value.authorisation_type, local.default_authorisation_type) == "JWT" ? each.value.authorisation_scopes : null
}

resource "aws_lambda_permission" "api" {
  for_each = var.routes

  statement_id  = "AllowExecutionFrom${replace(replace(each.key, "-", ""), "_", "")}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/${aws_apigatewayv2_stage.this.name}/${local.route_permissions[each.key].method}${local.route_permissions[each.key].path}"
}
