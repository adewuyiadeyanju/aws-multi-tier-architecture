provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "FieldOps"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}