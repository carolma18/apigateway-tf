# =============================================================================
# Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "rest_api_name" {
  description = "Name of the REST API Gateway"
  type        = string
  default     = "darkside-api"
}

variable "domain_name" {
  description = "Custom domain name for the API"
  type        = string
  default     = "api.darkside.dev.latam.com"
}

variable "enable_custom_domain" {
  description = "Set to true ONLY after DNS validation records exist in Cloudflare. Phase 1: false, Phase 2: true"
  type        = bool
  default     = false
}
