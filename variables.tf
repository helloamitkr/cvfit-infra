variable "aws_region" {
  description = "AWS region for all resources (except ACM which is always us-east-1)"
  type        = string
  default     = "ap-south-1" # Mumbai — closest to India
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}

variable "app_name" {
  description = "Application name used as prefix for all resources"
  type        = string
  default     = "cvfit"
}

# ── Domain ───────────────────────────────────────────────────────────────────

variable "domain_name" {
  description = "Primary domain name (e.g. zustresume.com). Leave empty to use CloudFront default domain."
  type        = string
  default     = ""
}

# ── Secrets (set via terraform.tfvars or CI env vars — never commit values) ──

variable "jwt_secret" {
  description = "JWT signing secret (min 32 chars)"
  type        = string
  sensitive   = true
}

variable "razorpay_key_id" {
  description = "Razorpay Key ID"
  type        = string
  sensitive   = true
}

variable "razorpay_key_secret" {
  description = "Razorpay Key Secret"
  type        = string
  sensitive   = true
}

variable "google_client_id" {
  description = "Google OAuth Client ID (leave empty to disable Google login)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "google_client_secret" {
  description = "Google OAuth Client Secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_client_id" {
  description = "GitHub OAuth Client ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_client_secret" {
  description = "GitHub OAuth Client Secret"
  type        = string
  default     = ""
  sensitive   = true
}

# ── AI ───────────────────────────────────────────────────────────────────────

variable "gemini_api_key" {
  description = "Google Gemini API key (from aistudio.google.com). Leave empty to fall back to Ollama."
  type        = string
  default     = ""
  sensitive   = true
}

variable "admin_emails" {
  description = "Comma-separated emails granted admin access (no DynamoDB is_admin flag needed)."
  type        = string
  default     = ""
}

# ── Email ─────────────────────────────────────────────────────────────────────

variable "ses_from_email" {
  description = "Verified SES sender email address"
  type        = string
  default     = "helloamit3107@gmail.com"
}

# ── Lambda ────────────────────────────────────────────────────────────────────

variable "lambda_memory_mb" {
  description = "Lambda memory in MB. 1024+ recommended for headless Chrome."
  type        = number
  default     = 1024
}

variable "lambda_timeout_seconds" {
  description = "Lambda timeout in seconds. Chrome PDF can take 15-30s."
  type        = number
  default     = 60
}

variable "lambda_image_tag" {
  description = "Docker image tag to deploy (set by CI pipeline)"
  type        = string
  default     = "latest"
}
