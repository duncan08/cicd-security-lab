terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # Remote state in S3, locked via DynamoDB (see PORTFOLIO.md Stage 8).
  # "bucket" and "key" are intentionally left out of this file and supplied
  # at `terraform init` time via -backend-config flags instead:
  #   -backend-config="bucket=$TF_STATE_BUCKET"   (a GitHub secret — keeps
  #                                                 the AWS account ID, which
  #                                                 the bucket name embeds
  #                                                 for global uniqueness,
  #                                                 out of version control)
  #   -backend-config="key=<environment>/terraform.tfstate"
  # This also means dev and prod get separate, non-overlapping state files
  # in the same bucket without needing Terraform workspaces.
  backend "s3" {
    region         = "us-east-1"
    dynamodb_table = "cicd-security-lab-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
