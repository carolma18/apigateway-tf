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

variable "lambda_function_arn" {
  description = "ARN of the Lambda function to integrate with"
  type        = string
  default     = "arn:aws:lambda:us-east-1:518222289458:function:aws-lambda-test"
}

variable "endpoints" {
  description = "Map of endpoints and their sub-resources. Each endpoint can have multiple resources."
  type = map(object({
    resources = list(string)
  }))
  default = {
    "gst-agent" = {
      resources = ["correct-name"]
    }
    "notification-service" = {
      resources = ["webhook"]
    }
  }
}
