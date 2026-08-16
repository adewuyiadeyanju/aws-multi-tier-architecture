resource "aws_vpc" "fieldops" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "fieldops-${var.environment}-vpc"
  }
}