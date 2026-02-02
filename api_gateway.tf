# =============================================================================
# REST API Gateway - darkside-api
# =============================================================================

resource "aws_api_gateway_rest_api" "main" {
  name        = var.rest_api_name
  description = "Darkside REST API with custom domain"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = var.rest_api_name
    Environment = "dev"
  }
}

# =============================================================================
# API Resources: Dynamic endpoints with for_each
# =============================================================================

# Create main endpoint resources (e.g., /gst-agent, /notification-service)
resource "aws_api_gateway_resource" "endpoints" {
  for_each    = var.endpoints
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = each.key
}

# Create sub-resources for each endpoint (e.g., /gst-agent/correct-name)
resource "aws_api_gateway_resource" "endpoint_resources" {
  for_each = {
    for pair in flatten([
      for endpoint_name, endpoint_config in var.endpoints : [
        for resource_name in endpoint_config.resources : {
          key           = "${endpoint_name}/${resource_name}"
          endpoint_name = endpoint_name
          resource_name = resource_name
        }
      ]
    ]) : pair.key => pair
  }
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.endpoints[each.value.endpoint_name].id
  path_part   = each.value.resource_name
}

# =============================================================================
# Methods - ANY on all resources with API Key required
# =============================================================================

# Methods for main endpoints
resource "aws_api_gateway_method" "endpoints" {
  for_each         = aws_api_gateway_resource.endpoints
  rest_api_id      = aws_api_gateway_rest_api.main.id
  resource_id      = each.value.id
  http_method      = "ANY"
  authorization    = "NONE"
  api_key_required = true
}

# Methods for sub-resources
resource "aws_api_gateway_method" "endpoint_resources" {
  for_each         = aws_api_gateway_resource.endpoint_resources
  rest_api_id      = aws_api_gateway_rest_api.main.id
  resource_id      = each.value.id
  http_method      = "ANY"
  authorization    = "NONE"
  api_key_required = true
}

# =============================================================================
# Lambda Integration
# =============================================================================

locals {
  lambda_arn = var.lambda_function_arn
}

# Lambda integrations for main endpoints
resource "aws_api_gateway_integration" "endpoints" {
  for_each                 = aws_api_gateway_method.endpoints
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = each.value.resource_id
  http_method             = each.value.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${local.lambda_arn}/invocations"
}

# Lambda integrations for sub-resources
resource "aws_api_gateway_integration" "endpoint_resources" {
  for_each                 = aws_api_gateway_method.endpoint_resources
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = each.value.resource_id
  http_method             = each.value.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${local.lambda_arn}/invocations"
}

# =============================================================================
# Lambda Permission - Allow API Gateway to invoke Lambda
# =============================================================================

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# =============================================================================
# Deployment and Stage
# =============================================================================

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      # All endpoint resources
      for endpoint in aws_api_gateway_resource.endpoints : {
        id = endpoint.id
      },
      # All sub-resources
      for resource in aws_api_gateway_resource.endpoint_resources : {
        id = resource.id
      },
      # All methods
      for method in aws_api_gateway_method.endpoints : {
        id = method.id
      },
      for method in aws_api_gateway_method.endpoint_resources : {
        id = method.id
      },
      # All integrations
      for integration in aws_api_gateway_integration.endpoints : {
        id  = integration.id
        uri = integration.uri
      },
      for integration in aws_api_gateway_integration.endpoint_resources : {
        id  = integration.id
        uri = integration.uri
      },
      # Force redeploy timestamp - change this to force a new deployment
      "2026-02-02T12:19:00",
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.endpoints,
    aws_api_gateway_integration.endpoint_resources,
  ]
}

resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = "dev"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId         = "$context.requestId"
      ip                = "$context.identity.sourceIp"
      caller            = "$context.identity.caller"
      user              = "$context.identity.user"
      requestTime       = "$context.requestTime"
      httpMethod        = "$context.httpMethod"
      resourcePath      = "$context.resourcePath"
      status            = "$context.status"
      protocol          = "$context.protocol"
      responseLength    = "$context.responseLength"
      integrationStatus = "$context.integrationStatus"
    })
  }

  tags = {
    Name        = "${var.rest_api_name}-dev"
    Environment = "dev"
  }

  depends_on = [aws_cloudwatch_log_group.api_gateway]
}
