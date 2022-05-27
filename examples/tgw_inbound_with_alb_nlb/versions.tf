terraform {
  required_version = ">= 0.13.7, < 2.0.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.region
}