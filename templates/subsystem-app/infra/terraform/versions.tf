terraform {
  required_version = ">= 1.7, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Backend settings are supplied by the deploy workflow via -backend-config
  # (bucket / key / region), so the same root serves every environment.
  backend "s3" {}
}
