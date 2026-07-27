terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.44.0"
    }
  }
}
provider "aws" {
  profile = var.aws_profile
  region  = var.primary_region
}

provider "aws" {
  alias   = "use2"
  profile = var.aws_profile
  region  = var.secondary_region
}