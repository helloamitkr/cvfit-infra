#!/bin/bash
# Runs inside the LocalStack container on startup via the ready.d hook.
set -euo pipefail

REGION="ap-south-1"
TABLE="cvfit-resumes-dev"
BUCKET="cvfit-resume-pdfs-dev"

echo "==> Creating DynamoDB table: $TABLE"
awslocal dynamodb create-table \
  --table-name "$TABLE" \
  --billing-mode PAY_PER_REQUEST \
  --attribute-definitions \
    AttributeName=id,AttributeType=S \
    AttributeName=userId,AttributeType=S \
    AttributeName=createdAt,AttributeType=S \
  --key-schema \
    AttributeName=id,KeyType=HASH \
  --global-secondary-indexes '[
    {
      "IndexName": "userId-createdAt-index",
      "KeySchema": [
        {"AttributeName": "userId", "KeyType": "HASH"},
        {"AttributeName": "createdAt", "KeyType": "RANGE"}
      ],
      "Projection": {"ProjectionType": "ALL"}
    }
  ]' \
  --region "$REGION"

echo "==> Creating S3 bucket: $BUCKET"
awslocal s3api create-bucket \
  --bucket "$BUCKET" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"

echo "==> LocalStack init complete"
awslocal dynamodb list-tables --region "$REGION"
awslocal s3api list-buckets
