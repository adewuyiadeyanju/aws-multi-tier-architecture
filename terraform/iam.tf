resource "aws_iam_role" "application" {
  name = "fieldops-${var.environment}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "fieldops-${var.environment}-app-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.application.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "application" {
  name = "fieldops-${var.environment}-app-profile"
  role = aws_iam_role.application.name

  tags = {
    Name = "fieldops-${var.environment}-app-profile"
  }
}