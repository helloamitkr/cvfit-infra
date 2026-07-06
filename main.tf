terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  # Remote state — create this bucket manually once, then uncomment.
  # backend "s3" {
  #   bucket = "cvfit-terraform-state"
  #   key    = "prod/terraform.tfstate"
  #   region = var.aws_region
  #   encrypt = true
  # }
}

provider "aws" {
  region  = var.aws_region
  profile = "terraform"

  default_tags {
    tags = {
      Project     = "CVFit"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# CloudFront requires ACM certificate in us-east-1 regardless of region.
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = "terraform"

  default_tags {
    tags = {
      Project     = "CVFit"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
