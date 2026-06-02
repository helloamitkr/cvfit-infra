# Resume PDFs bucket
# Bucket name includes account ID to guarantee global uniqueness.

resource "aws_s3_bucket" "resume_pdfs" {
  bucket = "cvfit-resume-pdfs-${var.environment}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "resume_pdfs" {
  bucket = aws_s3_bucket.resume_pdfs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "resume_pdfs" {
  bucket = aws_s3_bucket.resume_pdfs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "resume_pdfs" {
  bucket = aws_s3_bucket.resume_pdfs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "resume_pdfs" {
  bucket = aws_s3_bucket.resume_pdfs.id

  rule {
    id     = "expire-pdfs"
    status = "Enabled"

    filter {
      prefix = "resumes/"
    }

    expiration {
      days = var.pdf_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
