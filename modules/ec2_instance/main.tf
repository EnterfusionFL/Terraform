terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.44.0"
    }
  }
}
provider "aws" {
  region = "us-east-1"
}



resource "aws_instance" "test_vm" {
  ami           = "ami-0a59ec92177ec3fad"
  instance_type = "t2.micro"
  tags = {
    name = "test_VM"
  }
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.test_vm.id
}