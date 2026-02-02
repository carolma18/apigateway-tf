# =============================================================================
# Custom Domain Configuration
# =============================================================================
# CRITICAL: These resources depend on the ACM certificate being validated
# The certificate validation requires DNS records in Cloudflare to exist first
# =============================================================================

resource "aws_api_gateway_domain_name" "main" {
  domain_name              = var.domain_name
  regional_certificate_arn = aws_acm_certificate_validation.api.certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  security_policy = "TLS_1_2"

  tags = {
    Name        = var.domain_name
    Environment = "dev"
  }

  # Explicit dependency: Only create after certificate is validated
  depends_on = [aws_acm_certificate_validation.api]
}

resource "aws_api_gateway_base_path_mapping" "main" {
  api_id      = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  domain_name = aws_api_gateway_domain_name.main.domain_name

  # No base_path means the API is mapped to the root of the domain
  # Requests to api.agent-gss.dev.latam.com/gst-agent will route correctly

  depends_on = [
    aws_api_gateway_domain_name.main,
    aws_api_gateway_stage.prod,
  ]
}
