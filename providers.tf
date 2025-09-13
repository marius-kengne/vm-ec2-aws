terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.65.0"
    }
  }

  required_version = "1.13.0"

}

provider "aws" {
  region                   = var.app_region
  shared_credentials_files = ["./.Secrets/credentials"]
  profile                  = "ppd"
}
