terraform {
  required_providers {
    aws = {
      version = ">= 3.32.0"
      source = "hashicorp/aws"
    }
  }
  required_version = ">= 0.13"
}

provider "aws" {
  region  = "ap-southeast-2"
}
