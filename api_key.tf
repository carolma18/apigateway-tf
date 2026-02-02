# =============================================================================
# API Key and Usage Plan
# =============================================================================

resource "aws_api_gateway_api_key" "main" {
  name        = "${var.rest_api_name}-key"
  description = "API Key for GST Chatbot API"
  enabled     = true

  tags = {
    Name        = "${var.rest_api_name}-key"
    Environment = "dev"
  }
}

resource "aws_api_gateway_usage_plan" "main" {
  name        = "${var.rest_api_name}-usage-plan"
  description = "Usage plan with 10,000 requests per month quota"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.prod.stage_name
  }

  quota_settings {
    limit  = 10000
    period = "MONTH"
  }

  # Optional: Add throttling for burst protection
  throttle_settings {
    burst_limit = 50
    rate_limit  = 100
  }

  tags = {
    Name        = "${var.rest_api_name}-usage-plan"
    Environment = "dev"
  }

  depends_on = [aws_api_gateway_stage.prod]
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.main.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.main.id
}
