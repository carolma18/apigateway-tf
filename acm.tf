# =============================================================================
# ACM Certificate with DNS Validation
# =============================================================================
# Phase 1: Certificate is created, DNS validation records output for Cloudflare
# Phase 2: After DNS records exist, certificate validates automatically
# =============================================================================

resource "aws_acm_certificate" "api" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    Name        = "gst-chatbot-api-cert"
    Environment = "dev"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# This resource will wait for the certificate to be validated
# It requires the DNS records to exist in Cloudflare BEFORE it can complete
resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for record in aws_acm_certificate.api.domain_validation_options : record.resource_record_name]

  timeouts {
    create = "30m"
  }
}
