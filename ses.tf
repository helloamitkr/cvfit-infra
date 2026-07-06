# ── SES — email sending ───────────────────────────────────────────────────────
# Domain identity with DKIM so auth@zustresume.com can send mail.
# After terraform apply, add the DNS records from ses_dkim_records output to Namecheap.
# SES starts in sandbox — request production access in AWS console to send to any address.

locals {
  # If ses_from_email is a custom domain address (not gmail/yahoo/etc), verify the domain.
  ses_domain = var.domain_name != "" ? var.domain_name : ""
}

# Domain identity (used when domain_name is set)
resource "aws_sesv2_email_identity" "domain" {
  count         = local.ses_domain != "" ? 1 : 0
  email_identity = local.ses_domain

  dkim_signing_attributes {
    next_signing_key_length = "RSA_2048_BIT"
  }
}

# Fallback: email address identity (used when no custom domain)
resource "aws_ses_email_identity" "sender" {
  count = local.ses_domain == "" ? 1 : 0
  email = var.ses_from_email
}

# Dev sender — kept verified so local dev can send via helloamit3107@gmail.com
resource "aws_ses_email_identity" "dev_sender" {
  count = local.ses_domain != "" ? 1 : 0
  email = "helloamit3107@gmail.com"
}

resource "aws_ses_configuration_set" "default" {
  name = "${var.app_name}-${var.environment}"

  delivery_options {
    tls_policy = "Require"
  }

  reputation_metrics_enabled = true
  sending_enabled            = true
}

output "ses_identity_arn" {
  description = "SES identity ARN"
  value = local.ses_domain != "" ? (
    length(aws_sesv2_email_identity.domain) > 0 ? aws_sesv2_email_identity.domain[0].arn : ""
  ) : (
    length(aws_ses_email_identity.sender) > 0 ? aws_ses_email_identity.sender[0].arn : ""
  )
}

output "ses_dkim_records" {
  description = "Add these 3 CNAME records to Namecheap DNS to enable DKIM for zustresume.com"
  value = local.ses_domain != "" && length(aws_sesv2_email_identity.domain) > 0 ? {
    for token in aws_sesv2_email_identity.domain[0].dkim_signing_attributes[0].tokens :
    "${token}._domainkey" => "${token}.dkim.amazonses.com"
  } : {}
}

output "ses_sandbox_warning" {
  value = "SES is in sandbox mode. After adding DKIM records, request production access via AWS Console → SES → Account dashboard → Request production access."
}
