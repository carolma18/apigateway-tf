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
# API Resources: /gst-agent and /gst-agent/correct-name
# =============================================================================

resource "aws_api_gateway_resource" "gst_agent" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "gst-agent"
}

resource "aws_api_gateway_resource" "correct_name" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.gst_agent.id
  path_part   = "correct-name"
}

# =============================================================================
# Methods - ANY on both resources with API Key required
# =============================================================================

resource "aws_api_gateway_method" "gst_agent_any" {
  rest_api_id      = aws_api_gateway_rest_api.main.id
  resource_id      = aws_api_gateway_resource.gst_agent.id
  http_method      = "ANY"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method" "correct_name_any" {
  rest_api_id      = aws_api_gateway_rest_api.main.id
  resource_id      = aws_api_gateway_resource.correct_name.id
  http_method      = "ANY"
  authorization    = "NONE"
  api_key_required = true
}

# =============================================================================
# Lambda Integration
# =============================================================================

locals {
  lambda_arn = "arn:aws:lambda:us-east-1:518222289458:function:aws-lambda-test"
}

resource "aws_api_gateway_integration" "gst_agent_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.gst_agent.id
  http_method             = aws_api_gateway_method.gst_agent_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${local.lambda_arn}/invocations"
}

resource "aws_api_gateway_integration" "correct_name_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.correct_name.id
  http_method             = aws_api_gateway_method.correct_name_any.http_method
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
  function_name = "aws-lambda-test"
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
      aws_api_gateway_resource.gst_agent.id,
      aws_api_gateway_resource.correct_name.id,
      aws_api_gateway_method.gst_agent_any.id,
      aws_api_gateway_method.correct_name_any.id,
      aws_api_gateway_integration.gst_agent_lambda.id,
      aws_api_gateway_integration.gst_agent_lambda.uri,
      aws_api_gateway_integration.correct_name_lambda.id,
      aws_api_gateway_integration.correct_name_lambda.uri,
      # Force redeploy timestamp - change this to force a new deployment
      "2026-02-02T12:19:00",
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.gst_agent_lambda,
    aws_api_gateway_integration.correct_name_lambda,
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
