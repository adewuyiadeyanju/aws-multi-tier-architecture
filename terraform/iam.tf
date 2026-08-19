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

resource "aws_iam_role_policy" "database_secret_read" {
  name = "fieldops-${var.environment}-database-secret-read"
  role = aws_iam_role.application.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue"
        ]

        Resource = aws_db_instance.fieldops.master_user_secret[0].secret_arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "application" {
  name = "fieldops-${var.environment}-app-profile"
  role = aws_iam_role.application.name

  tags = {
    Name = "fieldops-${var.environment}-app-profile"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.application.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}