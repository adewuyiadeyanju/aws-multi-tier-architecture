resource "aws_ecr_repository" "fieldops" {
  name                 = "fieldops-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "fieldops-${var.environment}-ecr"
  }
}