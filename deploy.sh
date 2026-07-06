#!/usr/bin/env bash
# CVFit full-stack deployment script
# Usage: ./deploy.sh [backend|frontend|infra|all]
set -euo pipefail

# ── Config (edit these) ───────────────────────────────────────────────────────
AWS_REGION="${AWS_REGION:-ap-south-2}"
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --profile terraform --query Account --output text)"
ENV="${DEPLOY_ENV:-prod}"
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo latest)}"

# Read ECR URL directly from Terraform output — avoids any app_name mismatch
ECR_REPO="$(terraform -chdir="$(dirname "$0")" output -raw ecr_repository_url 2>/dev/null)"
if [ -z "$ECR_REPO" ]; then
  echo "ERROR: Could not get ecr_repository_url from Terraform. Run 'terraform apply' first."
  exit 1
fi

FRONTEND_DIR="$(cd "$(dirname "$0")/../cvfit-frontend" && pwd)"
BACKEND_DIR="$(cd "$(dirname "$0")/../cvfit-backend" && pwd)"
INFRA_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Helpers ───────────────────────────────────────────────────────────────────
log() { echo -e "\n\033[1;34m▶ $*\033[0m"; }
ok()  { echo -e "\033[1;32m✓ $*\033[0m"; }

# ── Get Terraform outputs ─────────────────────────────────────────────────────
tf_output() { terraform -chdir="$INFRA_DIR" output -raw "$1" 2>/dev/null || echo ""; }

# ─────────────────────────────────────────────────────────────────────────────
deploy_infra() {
  log "Deploying infrastructure (Terraform)"
  cd "$INFRA_DIR"
  terraform init
  terraform plan -out=tfplan
  terraform apply tfplan
  ok "Infrastructure deployed"
}

# ─────────────────────────────────────────────────────────────────────────────
deploy_backend() {
  log "Cross-compiling Go binary for linux/amd64..."
  cd "$BACKEND_DIR"
  GOOS=linux GOARCH=amd64 CGO_ENABLED=0 \
    go build -ldflags="-s -w" -o lambda ./cmd/lambda/
  ok "Binary compiled: cvfit-backend/lambda"

  log "Building and pushing Docker image (Chromium only, no Go inside)"

  # Authenticate Docker to ECR (registry host extracted from the repo URL)
  ECR_REGISTRY="$(echo "$ECR_REPO" | cut -d'/' -f1)"
  aws ecr get-login-password --region "$AWS_REGION" --profile terraform \
    | docker login --username AWS --password-stdin "$ECR_REGISTRY"

  # Build context is cvfit-backend/ — binary already there from step above
  docker build \
    --pull \
    --platform linux/amd64 \
    -f "${BACKEND_DIR}/Dockerfile" \
    -t "${ECR_REPO}:${IMAGE_TAG}" \
    -t "${ECR_REPO}:latest" \
    "${BACKEND_DIR}"

  docker push "${ECR_REPO}:${IMAGE_TAG}"
  docker push "${ECR_REPO}:latest"

  rm -f "${BACKEND_DIR}/lambda"   # clean up local cross-compiled binary

  ok "Image pushed: ${ECR_REPO}:${IMAGE_TAG}"

  log "Updating Lambda function image"
  LAMBDA_NAME="$(tf_output lambda_function_name)"
  if [ -z "$LAMBDA_NAME" ]; then
    LAMBDA_NAME="${APP_NAME}-${ENV}-backend"
  fi

  aws lambda update-function-code \
    --function-name "$LAMBDA_NAME" \
    --image-uri "${ECR_REPO}:${IMAGE_TAG}" \
    --region "$AWS_REGION" \
    --output table

  # Wait for update to finish before returning
  aws lambda wait function-updated \
    --function-name "$LAMBDA_NAME" \
    --region "$AWS_REGION"

  ok "Lambda updated to image tag: ${IMAGE_TAG}"
}

# ─────────────────────────────────────────────────────────────────────────────
deploy_frontend() {
  log "Building Next.js static export"
  cd "$FRONTEND_DIR"
  npm ci --prefer-offline
  # Explicitly pass API URL — .env.local (localhost) overrides .env.production otherwise
  NEXT_PUBLIC_API_URL="$(terraform -chdir="${INFRA_DIR}" output -raw api_base_url)/api" \
    npm run build   # produces /out directory (output: "export" in next.config.ts)

  S3_BUCKET="$(tf_output frontend_s3_bucket)"
  CF_DIST_ID="$(tf_output cloudfront_distribution_id)"

  if [ -z "$S3_BUCKET" ]; then
    echo "ERROR: Could not get S3 bucket from Terraform outputs. Run deploy_infra first."
    exit 1
  fi

  log "Syncing to S3 bucket: ${S3_BUCKET}"
  # Upload with long cache for hashed assets, short cache for HTML
  aws s3 sync out/ "s3://${S3_BUCKET}/" \
    --region "$AWS_REGION" \
    --delete \
    --cache-control "public,max-age=31536000,immutable" \
    --exclude "*.html"

  aws s3 sync out/ "s3://${S3_BUCKET}/" \
    --region "$AWS_REGION" \
    --cache-control "public,max-age=0,must-revalidate" \
    --include "*.html"

  ok "S3 sync complete"

  log "Invalidating CloudFront cache"
  aws cloudfront create-invalidation \
    --distribution-id "$CF_DIST_ID" \
    --paths "/*" \
    --region us-east-1 \
    --output table

  ok "CloudFront cache invalidated"
}

# ─────────────────────────────────────────────────────────────────────────────
COMMAND="${1:-all}"
case "$COMMAND" in
  infra)    deploy_infra ;;
  backend)  deploy_backend ;;
  frontend) deploy_frontend ;;
  all)
    deploy_infra
    deploy_backend
    deploy_frontend
    echo -e "\n\033[1;32m🚀 Full deployment complete!\033[0m"
    echo "Frontend: $(tf_output frontend_url)"
    echo "API:      $(tf_output api_base_url)"
    ;;
  *)
    echo "Usage: $0 [infra|backend|frontend|all]"
    exit 1
    ;;
esac
