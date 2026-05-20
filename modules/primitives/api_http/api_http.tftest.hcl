mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "valid_http_api_contract" {
  command = plan

  variables {
    name = "contract-api"
    routes = {
      smoke = {
        route_key            = "GET /smoke"
        lambda_function_arn  = "arn:aws:lambda:eu-west-2:123456789012:function:smoke"
        lambda_function_name = "smoke"
      }
    }
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = aws_apigatewayv2_api.this.protocol_type == "HTTP"
    error_message = "The module must create an HTTP API."
  }

  assert {
    condition     = local.route_permissions["smoke"].method == "GET" && local.route_permissions["smoke"].path == "/smoke"
    error_message = "Per-route source_arn parsing must split the route_key into the literal method and path so each Lambda permission is scoped to its own route."
  }
}

run "scopes_proxy_route_source_arn" {
  command = plan

  variables {
    name = "contract-api"
    routes = {
      proxy = {
        route_key            = "ANY /{proxy+}"
        lambda_function_arn  = "arn:aws:lambda:eu-west-2:123456789012:function:proxy"
        lambda_function_name = "proxy"
      }
    }
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = local.route_permissions["proxy"].method == "*"
    error_message = "ANY routes must resolve to a wildcard method in the lambda_permission source_arn."
  }

  assert {
    condition     = local.route_permissions["proxy"].path == "/*"
    error_message = "Path parameters such as {proxy+} must be rewritten to '*' so the lambda_permission source_arn is a valid API Gateway scope."
  }
}
