# =============================================================================
# REST API Gateway - gst-chatbot-api
# =============================================================================

resource "aws_api_gateway_rest_api" "main" {
  name        = var.rest_api_name
  description = "GST Chatbot REST API with custom domain"

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
# Mock Integrations (placeholder - replace with Lambda/HTTP integration)
# =============================================================================

resource "aws_api_gateway_integration" "gst_agent_mock" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.gst_agent.id
  http_method = aws_api_gateway_method.gst_agent_any.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_integration" "correct_name_mock" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.correct_name.id
  http_method = aws_api_gateway_method.correct_name_any.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# =============================================================================
# Mock Integration Responses
# =============================================================================

resource "aws_api_gateway_method_response" "gst_agent_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.gst_agent.id
  http_method = aws_api_gateway_method.gst_agent_any.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "gst_agent_mock" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.gst_agent.id
  http_method = aws_api_gateway_method.gst_agent_any.http_method
  status_code = aws_api_gateway_method_response.gst_agent_200.status_code

  response_templates = {
    "application/json" = jsonencode({
      message = "GST Agent endpoint - replace with Lambda integration"
    })
  }
}

resource "aws_api_gateway_method_response" "correct_name_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.correct_name.id
  http_method = aws_api_gateway_method.correct_name_any.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "correct_name_mock" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.correct_name.id
  http_method = aws_api_gateway_method.correct_name_any.http_method
  status_code = aws_api_gateway_method_response.correct_name_200.status_code

  response_templates = {
    "application/json" = jsonencode({
      message = "Correct Name endpoint - replace with Lambda integration"
    })
  }
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
      aws_api_gateway_integration.gst_agent_mock.id,
      aws_api_gateway_integration.correct_name_mock.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.gst_agent_mock,
    aws_api_gateway_integration.correct_name_mock,
    aws_api_gateway_integration_response.gst_agent_mock,
    aws_api_gateway_integration_response.correct_name_mock,
  ]
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = "prod"

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
    Name        = "${var.rest_api_name}-prod"
    Environment = "dev"
  }

  depends_on = [aws_cloudwatch_log_group.api_gateway]
}
