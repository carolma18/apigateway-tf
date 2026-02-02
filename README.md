# GST Chatbot API - Terraform Deployment Guide

## Overview

This Terraform configuration creates a **Regional AWS API Gateway REST API** with:
- Custom domain: `api.darkside.dev.latam.com`
- ACM certificate with DNS validation
- API Key authentication with 10,000 requests/month quota
- CloudWatch logging at INFO level

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Cloudflare DNS                                 │
│  api.darkside.dev.latam.com → CNAME → <regional_domain_name>             │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    AWS API Gateway (Regional)                            │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Custom Domain: api.darkside.dev.latam.com                       │    │
│  │  Certificate: ACM (DNS validated)                               │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                    │                                     │
│                                    ▼                                     │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  REST API: darkside-api                                          │    │
│  │  Stage: dev                                                    │    │
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
                    CloudWatch Logs (/aws/api-gateway/darkside)
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

### The Solution: `enable_custom_domain` Variable

#### Phase 1: Initial Apply (default)
```powershell
cd c:\code\apigateway-tf
terraform init
terraform apply
# enable_custom_domain = false (default)
```

**What gets created:**
- ✅ ACM Certificate (pending validation)
- ✅ REST API Gateway with all resources
- ✅ API Key and Usage Plan
- ✅ CloudWatch Log Group and IAM Role
- ✅ Custom Domain Name (generated `d-xxxx` target)
- ⏸️ Certificate Validation (skipped)
- ⏸️ Base Path Mapping (skipped)

**Outputs you need for Cloudflare PR:**
```hcl
# 1. Certificate Validation Record (CNAME)
acm_dns_validation_records = {
  "api.darkside.dev.latam.com" = {
    name  = "_xxxxxx.api.darkside.dev.latam.com."
    type  = "CNAME"
    value = "_yyyyyy.acm-validations.aws."
    ttl   = 300
  }
}

# 2. Custom Domain Target (CNAME)
api_gateway_regional_domain_name = "d-xxxxxxxxx.execute-api.us-east-1.amazonaws.com"
```

#### External Step: Cloudflare PR
Create DNS records in Cloudflare:

1. **ACM Validation Record** (required for Phase 2):
   ```
   Type: CNAME
   Name: _xxxxxx.api.darkside.dev.latam.com
   Target: _yyyyyy.acm-validations.aws
   Proxy: OFF (DNS only - grey cloud!)
   ```

2. **API Domain Record** (after Phase 2):
   ```
   Type: CNAME
   Name: api.darkside.dev.latam.com
   Target: <api_gateway_regional_domain_name from output>
   Proxy: ON or OFF (your choice)
   ```

#### Phase 2: After DNS Propagation
Wait 5-30 minutes for DNS to propagate, then:
```powershell
terraform apply -var="enable_custom_domain=true"
```

**What gets created:**
- ✅ Certificate Validation (waits for validation)
- ✅ Custom Domain
- ✅ Base Path Mapping

---

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region |
| `rest_api_name` | `darkside-api` | Name of the REST API |
| `domain_name` | `api.darkside.dev.latam.com` | Custom domain |
| `enable_custom_domain` | `false` | **Phase 1: false, Phase 2: true** |

Override with `terraform.tfvars`:
```hcl
aws_region           = "us-east-1"
rest_api_name        = "darkside-api"
domain_name          = "api.darkside.dev.latam.com"
enable_custom_domain = false  # Set to true for Phase 2
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
curl -H "x-api-key: $API_KEY" https://api.darkside.dev.latam.com/gst-agent
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


###
Output:
acm_certificate_arn = "arn:aws:acm:us-east-1:518222289458:certificate/21f35244-f931-43ee-be8a-a885847e159f"
acm_dns_validation_records = {
  "api.darkside.dev.latam.com" = {
    "name" = "_517a8d14f7ddc85b0b3fdfe08783efc7.api.darkside.dev.latam.com."
    "ttl" = 300
    "type" = "CNAME"
    "value" = "_ae613d3f735cfe73b8503331df27ee17.jkddzztszm.acm-validations.aws."
  }
}
api_gateway_regional_domain_name = "Run Phase 2 with enable_custom_domain=true"
api_gateway_regional_zone_id = "Run Phase 2 with enable_custom_domain=true"
api_key_id = "7ttw10mk52"
api_key_value = <sensitive>
cloudwatch_log_group = "/aws/api-gateway/darkside"
custom_domain_url = "https://api.darkside.dev.latam.com"
rest_api_base_url = "https://axyy5rmux4.execute-api.us-east-1.amazonaws.com/dev"
rest_api_invoke_url = "arn:aws:execute-api:us-east-1:518222289458:axyy5rmux4/dev"


Phase 1 (Apply NOW): Only the ACM Validation record will be in the output. Use this to create the first PR.
powershell
terraform apply
External (Wait): Create the validation CNAME in Cloudflare. Wait for the certificate status to become "Issued" in the AWS console (~5-10 mins).
Phase 2 (After Issued): Run the apply with the flag. This will finally create the Domain Name and provide the d-xxxx target you need for the final PR.
powershell
terraform apply -var="enable_custom_domain=true"

Entonces:
1. Ejecutar terraform apply
2. Crear el PR con el output de acm_dns_validation_records
3. Esperar a que el certificado se valide (pase de pending a issued)
4. Ejecutar terraform apply -var="enable_custom_domain=true"
5. Crear el PR con el output de api_gateway_regional_domain_name