terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    region       = "eu-north-1"
    key          = "training-eks/infra.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
provider "aws" {
  region = "eu-north-1"
  default_tags {
    tags = { Project = "training-eks", Environment = "lab" }
  }
}
