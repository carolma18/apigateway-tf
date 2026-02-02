# =============================================================================
# CloudWatch Logging for API Gateway
# =============================================================================

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/api-gateway/darkside"
  retention_in_days = 30

  tags = {
    Name        = "${var.rest_api_name}-logs"
    Environment = "dev"
  }
}

# =============================================================================
# API Gateway Account Settings (CloudWatch Role)
# =============================================================================
# Note: This is a global setting per AWS account/region
# Only one aws_api_gateway_account resource should exist per region
# =============================================================================

resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${var.rest_api_name}-api-gateway-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.rest_api_name}-cloudwatch-role"
    Environment = "dev"
  }
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn

  depends_on = [aws_iam_role_policy_attachment.api_gateway_cloudwatch]
}

# =============================================================================
# Method Settings for INFO Level Logging
# =============================================================================

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.dev.stage_name
  method_path = "*/*"

  settings {
    logging_level          = "INFO"
    data_trace_enabled     = true
    metrics_enabled        = true
    throttling_burst_limit = 50
    throttling_rate_limit  = 100
  }

  depends_on = [
    aws_api_gateway_account.main,
    aws_api_gateway_stage.dev,
  ]
}
