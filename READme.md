# cvfit-infra

Terraform for the ZustResume (CVFit) AWS stack. Region: **ap-south-2** (Hyderabad).

## Resources

| File | Provisions |
|------|-----------|
| `lambda.tf` | Go backend as a container Lambda (env vars for AI, Razorpay, OAuth, SES, tables) |
| `apigateway.tf` | HTTP API in front of the Lambda |
| `dynamodb.tf` | `users` (with email GSI), `orders`, `requests` tables |
| `s3.tf` | Frontend static-site bucket + receipts |
| `cloudfront.tf` | CDN for the frontend (with an index-rewrite function) |
| `ecr.tf` / `ecr_push.tf` | Container registry + initial image push for the Lambda |
| `ses.tf` | Email identity/config for transactional mail |
| `ssm.tf` | Parameter store prefix for secrets |
| `iam.tf` | Lambda execution role + policies |
| `variables.tf` | All inputs (secrets, client IDs, region, app name) |

## Usage

```bash
terraform init
terraform plan      # requires network/DNS to AWS + valid credentials
terraform apply
```

Secrets go in **`terraform.tfvars`** (gitignored) — e.g. `gemini_api_key`, `razorpay_key_id/secret`, `jwt_secret`, `google_client_id/secret`, `ses_from_email`. The Lambda reads these as environment variables (see `lambda.tf`).

> **Note:** `ap-south-2` is an opt-in region; ensure it's enabled on the account. A `dial tcp … no such host` on plan is a **local DNS/VPN** issue, not a config error — retry / flush DNS.

## Frontend deploy (after `npm run build` in `cvfit-frontend`)

```bash
aws s3 sync ../cvfit-frontend/out s3://<bucket> --delete
# ensure correct content-type on extension-less generated files if any
aws cloudfront create-invalidation --distribution-id <id> --paths "/*"
```
