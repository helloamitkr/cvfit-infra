# ── Lambda execution role ────────────────────────────────────────────────────

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "cvfit-api-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_app" {
  statement {
    sid    = "DynamoDBResumes"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = [
      aws_dynamodb_table.resumes.arn,
      "${aws_dynamodb_table.resumes.arn}/index/*",
    ]
  }

  statement {
    sid    = "S3PDFObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.resume_pdfs.arn}/resumes/*"]
  }

  statement {
    sid       = "S3ListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.resume_pdfs.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["resumes/*"]
    }
  }
}

resource "aws_iam_role_policy" "lambda_app" {
  name   = "cvfit-api-app-permissions"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_app.json
}

# ── GitHub Actions CI IAM user ───────────────────────────────────────────────
# This user's access keys go in GitHub Secrets:
#   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
#
# It can deploy Lambda code and run Terraform (with state in local or S3).

resource "aws_iam_user" "ci" {
  name = "cvfit-github-actions"
}

data "aws_iam_policy_document" "ci" {
  # Lambda: update function code only (Terraform manages config)
  statement {
    sid    = "LambdaDeploy"
    effect = "Allow"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:PublishVersion",
    ]
    resources = [aws_lambda_function.api.arn]
  }

  # Terraform needs to manage all cvfit resources
  statement {
    sid    = "TerraformManage"
    effect = "Allow"
    actions = [
      "dynamodb:*",
      "s3:*",
      "lambda:*",
      "apigateway:*",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetUser",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:PassRole",
      "logs:DescribeLogGroups",
      "logs:ListTagsForResource",
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/Project"
      values   = ["cvfit"]
    }
  }

  # Allow reading caller identity (needed by Terraform for account ID)
  statement {
    sid       = "STSIdentity"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "ci" {
  name   = "cvfit-ci-permissions"
  user   = aws_iam_user.ci.name
  policy = data.aws_iam_policy_document.ci.json
}

resource "aws_iam_access_key" "ci" {
  user = aws_iam_user.ci.name
}

output "ci_access_key_id" {
  description = "GitHub Actions AWS_ACCESS_KEY_ID secret"
  value       = aws_iam_access_key.ci.id
}

output "ci_secret_access_key" {
  description = "GitHub Actions AWS_SECRET_ACCESS_KEY secret"
  value       = aws_iam_access_key.ci.secret
  sensitive   = true
}
