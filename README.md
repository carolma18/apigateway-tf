# GST Chatbot API - Terraform Deployment Guide

## Overview

This Terraform configuration creates a **Regional AWS API Gateway REST API** with:
- Custom domain: `api.agent-gss.dev.latam.com`
- ACM certificate with DNS validation
- API Key authentication with 10,000 requests/month quota
- CloudWatch logging at INFO level

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Cloudflare DNS                                 │
│  api.agent-gss.dev.latam.com → CNAME → <regional_domain_name>           │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    AWS API Gateway (Regional)                            │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Custom Domain: api.agent-gss.dev.latam.com                     │    │
│  │  Certificate: ACM (DNS validated)                               │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                    │                                     │
│                                    ▼                                     │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  REST API: gst-chatbot-api                                      │    │
│  │  Stage: prod                                                    │    │
│  │  ├── /gst-agent          (ANY) - API Key Required               │    │
│  │  └── /gst-agent/correct-name (ANY) - API Key Required           │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                    │                                     │
│                                    ▼                                     │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Usage Plan: 10,000 requests/month                              │    │
│  │  Throttle: 100 req/sec, 50 burst                                │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                    CloudWatch Logs (/aws/api-gateway/gst-chatbot-api)
```

---

## Files Structure

| File | Description |
|------|-------------|
| `main.tf` | Terraform/provider configuration |
| `variables.tf` | Input variables (region, api_name, domain) |
| `acm.tf` | ACM certificate with DNS validation |
| `api_gateway.tf` | REST API, resources, methods, stage |
| `api_key.tf` | API Key and Usage Plan (10k/month) |
| `custom_domain.tf` | Custom domain + base path mapping |
| `cloudwatch.tf` | Log group, IAM role, method settings |
| `outputs.tf` | All outputs for Phase 1 & Phase 2 |

---

## Two-Phase Deployment (Chicken-and-Egg Solution)

### The Problem
- Custom domain requires a **validated** ACM certificate
- ACM certificate validation requires **DNS records** in Cloudflare
- DNS CNAME for the domain needs the **API Gateway regional domain name**
- But regional domain name only exists after custom domain is created

### The Solution

#### Phase 1: Initial Apply
```powershell
cd c:\code\apigateway-tf
terraform init
terraform apply
```

**What gets created:**
- ✅ ACM Certificate (pending validation)
- ✅ REST API Gateway with all resources
- ✅ API Key and Usage Plan
- ✅ CloudWatch Log Group and IAM Role
- ⏸️ Custom Domain (waiting for cert validation)
- ⏸️ Base Path Mapping (waiting for custom domain)

**Outputs you need for Cloudflare PR:**
```hcl
# Get these from terraform output
acm_dns_validation_records = {
  "api.agent-gss.dev.latam.com" = {
    name  = "_xxxxxx.api.agent-gss.dev.latam.com."
    type  = "CNAME"
    value = "_yyyyyy.acm-validations.aws."
    ttl   = 300
  }
}
```

#### External Step: Cloudflare PR
Create DNS records in Cloudflare:

1. **ACM Validation Record** (required for Phase 2):
   ```
   Type: CNAME
   Name: _xxxxxx.api.agent-gss.dev.latam.com
   Target: _yyyyyy.acm-validations.aws
   Proxy: OFF (DNS only - grey cloud!)
   ```

2. **API Domain Record** (after Phase 2):
   ```
   Type: CNAME
   Name: api.agent-gss.dev.latam.com
   Target: <api_gateway_regional_domain_name from output>
   Proxy: ON or OFF (your choice)
   ```

#### Phase 2: After DNS Propagation
Wait 5-30 minutes for certificate validation, then:
```powershell
terraform apply
```

**What gets created:**
- ✅ Custom Domain (now cert is validated)
- ✅ Base Path Mapping

---

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region |
| `rest_api_name` | `gst-chatbot-api` | Name of the REST API |
| `domain_name` | `api.agent-gss.dev.latam.com` | Custom domain |

Override with `terraform.tfvars`:
```hcl
aws_region    = "us-east-1"
rest_api_name = "gst-chatbot-api"
domain_name   = "api.agent-gss.dev.latam.com"
```

---

## Key Outputs

| Output | Phase | Purpose |
|--------|-------|---------|
| `acm_dns_validation_records` | 1 | DNS records for Cloudflare (certificate validation) |
| `api_gateway_regional_domain_name` | 2 | CNAME target for custom domain in Cloudflare |
| `api_gateway_regional_zone_id` | 2 | For Route53 alias (if needed) |
| `rest_api_base_url` | 1 | Direct API URL for testing |
| `api_key_value` | 1 | API key (sensitive, use `-raw` to view) |

View sensitive output:
```powershell
terraform output -raw api_key_value
```

---

## Testing the API

### Direct URL (after Phase 1):
```powershell
$API_KEY = terraform output -raw api_key_value
$BASE_URL = terraform output -raw rest_api_base_url

curl -H "x-api-key: $API_KEY" "$BASE_URL/gst-agent"
curl -H "x-api-key: $API_KEY" "$BASE_URL/gst-agent/correct-name"
```

### Custom Domain (after Phase 2 + DNS propagation):
```powershell
curl -H "x-api-key: $API_KEY" https://api.agent-gss.dev.latam.com/gst-agent
```

---

## Next Steps: Replace Mock Integration

The current setup uses **MOCK integrations** as placeholders. To connect to Lambda:

1. Add Lambda data source or resource
2. Replace integration type from `MOCK` to `AWS_PROXY`
3. Add Lambda permission for API Gateway
4. Update deployment triggers

Example Lambda integration in `api_gateway.tf`:
```hcl
resource "aws_api_gateway_integration" "gst_agent_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.gst_agent.id
  http_method             = aws_api_gateway_method.gst_agent_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.your_lambda.invoke_arn
}
```

---

## Troubleshooting

### Certificate stuck in "Pending validation"
- Verify DNS record exists in Cloudflare
- Ensure proxy is **OFF** (grey cloud) for validation CNAME
- Wait up to 30 minutes
- Check: `aws acm describe-certificate --certificate-arn <arn>`

### API returns 403 Forbidden
- Missing or invalid `x-api-key` header
- Check: `terraform output -raw api_key_value`

### Custom domain not resolving
- Check Cloudflare DNS propagation
- Verify CNAME points to `api_gateway_regional_domain_name`
- Wait for DNS TTL to expire
