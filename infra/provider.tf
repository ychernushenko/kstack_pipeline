provider "aws" {
  region = "eu-central-1"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 2.0.0"
    }
  }

  backend "s3" {
    bucket = "clouddatastack-infra"
    key    = "terraform/state"
    region = "eu-central-1"
  }
}
