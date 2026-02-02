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
  default     = "gst-chatbot-api"
}

variable "domain_name" {
  description = "Custom domain name for the API"
  type        = string
  default     = "api.agent-gss.dev.latam.com"
}
