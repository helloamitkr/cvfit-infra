# ── Initial image push ────────────────────────────────────────────────────────
# Go binary is cross-compiled on the host (avoids Go 1.26 Docker toolchain bug).
# Docker image only installs Chromium and copies the pre-built binary.
#
# This resource runs once when ECR is first created (triggers on ecr_url change).
# All subsequent deploys use: ./deploy.sh backend

locals {
  repo_root    = abspath("${path.module}/..")
  backend_dir  = abspath("${path.module}/../cvfit-backend")
  ecr_url      = aws_ecr_repository.backend.repository_url
}

resource "null_resource" "initial_image_push" {
  depends_on = [aws_ecr_repository.backend]

  triggers = {
    ecr_url = local.ecr_url
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      echo "==> Cross-compiling Go binary for linux/amd64..."
      cd "${local.backend_dir}"
      GOOS=linux GOARCH=amd64 CGO_ENABLED=0 \
        go build -ldflags="-s -w" -o lambda ./cmd/lambda/

      echo "==> Authenticating Docker to ECR..."
      aws ecr get-login-password \
        --region ${var.aws_region} \
        --profile terraform \
      | docker login \
          --username AWS \
          --password-stdin \
          ${local.ecr_url}

      echo "==> Building Docker image (Chromium install ~2 min)..."
      docker build \
        --platform linux/amd64 \
        -f "${local.backend_dir}/Dockerfile" \
        -t ${local.ecr_url}:latest \
        "${local.backend_dir}"

      echo "==> Pushing image to ECR..."
      docker push ${local.ecr_url}:latest

      echo "==> Cleaning up local binary..."
      rm -f "${local.backend_dir}/lambda"

      echo "==> Done. Image available at ${local.ecr_url}:latest"
    EOT
  }
}
