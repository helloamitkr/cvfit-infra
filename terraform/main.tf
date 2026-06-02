terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  # Uncomment after bootstrapping state bucket manually:
  #
  # backend "s3" {
  #   bucket         = "cvfit-terraform-state-<your-account-id>"
  #   key            = "cvfit/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "cvfit-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "cvfit"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
