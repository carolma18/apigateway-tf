variable "aws_region" {
  type = string
}

variable "lambda_function_name" {
  type = string
}

variable "api_name" {
  type    = string
  default = "http-api-existing-lambda"
}

