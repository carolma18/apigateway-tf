# =============================================================================
# Custom Domain Configuration
# =============================================================================
# CRITICAL: These resources depend on the ACM certificate being validated
# The certificate validation requires DNS records in Cloudflare to exist first
# Only created in Phase 2 when enable_custom_domain = true
# =============================================================================

resource "aws_api_gateway_domain_name" "main" {
  count                    = var.enable_custom_domain ? 1 : 0
  domain_name              = var.domain_name
  regional_certificate_arn = aws_acm_certificate_validation.api[0].certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  security_policy = "TLS_1_2"

  tags = {
    Name        = var.domain_name
    Environment = "dev"
  }

  depends_on = [aws_acm_certificate_validation.api]
}

resource "aws_api_gateway_base_path_mapping" "main" {
  count       = var.enable_custom_domain ? 1 : 0
  api_id      = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.dev.stage_name
  domain_name = aws_api_gateway_domain_name.main[0].domain_name

  depends_on = [
    aws_api_gateway_domain_name.main,
    aws_api_gateway_stage.dev,
  ]
}
