terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  shared_credentials_file = "/Users/fabio/.aws/credentials"
  profile                 = "devopsfabiolopes"
  region                  = "us-east-1"
}