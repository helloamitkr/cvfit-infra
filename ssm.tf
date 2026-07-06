# ── SSM Parameter Store — secrets ─────────────────────────────────────────────
# Lambda reads these at startup via env vars injected by the Lambda config.
# Stored as SecureString (KMS-encrypted).

locals {
  ssm_prefix = "/${var.app_name}/${var.environment}"
}

resource "aws_ssm_parameter" "jwt_secret" {
  name  = "${local.ssm_prefix}/jwt-secret"
  type  = "SecureString"
  value = var.jwt_secret
}

resource "aws_ssm_parameter" "razorpay_key_id" {
  name  = "${local.ssm_prefix}/razorpay-key-id"
  type  = "SecureString"
  value = var.razorpay_key_id
}

resource "aws_ssm_parameter" "razorpay_key_secret" {
  name  = "${local.ssm_prefix}/razorpay-key-secret"
  type  = "SecureString"
  value = var.razorpay_key_secret
}

resource "aws_ssm_parameter" "google_client_id" {
  count = var.google_client_id != "" ? 1 : 0
  name  = "${local.ssm_prefix}/google-client-id"
  type  = "SecureString"
  value = var.google_client_id
}

resource "aws_ssm_parameter" "google_client_secret" {
  count = var.google_client_secret != "" ? 1 : 0
  name  = "${local.ssm_prefix}/google-client-secret"
  type  = "SecureString"
  value = var.google_client_secret
}

resource "aws_ssm_parameter" "github_client_id" {
  count = var.github_client_id != "" ? 1 : 0
  name  = "${local.ssm_prefix}/github-client-id"
  type  = "SecureString"
  value = var.github_client_id
}

resource "aws_ssm_parameter" "github_client_secret" {
  count = var.github_client_secret != "" ? 1 : 0
  name  = "${local.ssm_prefix}/github-client-secret"
  type  = "SecureString"
  value = var.github_client_secret
}
