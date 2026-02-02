# =============================================================================
# Outputs - Phase 1: DNS Validation Records and Regional Domain
# =============================================================================
# Use these outputs to create DNS records in Cloudflare before Phase 2
# =============================================================================

# -----------------------------------------------------------------------------
# ACM Certificate Outputs
# -----------------------------------------------------------------------------

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.api.arn
}

output "acm_dns_validation_records" {
  description = "DNS validation records to create in Cloudflare for certificate validation"
  value = {
    for dvo in aws_acm_certificate.api.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      value  = dvo.resource_record_value
      ttl    = 300
      # Note: Disable Cloudflare proxy (orange cloud) for CNAME validation records
    }
  }
}

# -----------------------------------------------------------------------------
# API Gateway Regional Domain Outputs (for Cloudflare CNAME after validation)
# Only available after Phase 2 (enable_custom_domain = true)
# -----------------------------------------------------------------------------

output "api_gateway_regional_domain_name" {
  description = "Regional domain name of the API Gateway custom domain (CNAME target for Cloudflare)"
  value       = try(aws_api_gateway_domain_name.main[0].regional_domain_name, "Run Phase 2 with enable_custom_domain=true")
}

output "api_gateway_regional_zone_id" {
  description = "Regional hosted zone ID (for Route53 alias records if needed)"
  value       = try(aws_api_gateway_domain_name.main[0].regional_zone_id, "Run Phase 2 with enable_custom_domain=true")
}

# -----------------------------------------------------------------------------
# API Access Outputs
# -----------------------------------------------------------------------------

output "rest_api_invoke_url" {
  description = "Direct invoke URL for the REST API (without custom domain)"
  value       = "${aws_api_gateway_rest_api.main.execution_arn}/${aws_api_gateway_stage.dev.stage_name}"
}

output "rest_api_base_url" {
  description = "Base URL for the REST API stage"
  value       = aws_api_gateway_stage.dev.invoke_url
}

output "custom_domain_url" {
  description = "Custom domain URL (available after Phase 2 and Cloudflare DNS propagation)"
  value       = "https://${var.domain_name}"
}

# -----------------------------------------------------------------------------
# API Key Output (Sensitive)
# -----------------------------------------------------------------------------

output "api_key_id" {
  description = "ID of the API key"
  value       = aws_api_gateway_api_key.main.id
}

output "api_key_value" {
  description = "Value of the API key (use with x-api-key header)"
  value       = aws_api_gateway_api_key.main.value
  sensitive   = true
}

# -----------------------------------------------------------------------------
# CloudWatch Logs
# -----------------------------------------------------------------------------

output "cloudwatch_log_group" {
  description = "CloudWatch log group name for API Gateway logs"
  value       = aws_cloudwatch_log_group.api_gateway.name
}
