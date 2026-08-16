resource "aws_security_group" "alb" {
  name        = "fieldops-${var.environment}-alb-sg"
  description = "Security group for the FieldOps Application Load Balancer"
  vpc_id      = aws_vpc.fieldops.id

  ingress {
    description = "HTTP for HTTPS redirect"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fieldops-${var.environment}-alb-sg"
  }
}

resource "aws_security_group" "application" {
  name        = "fieldops-${var.environment}-app-sg"
  description = "Security group for FieldOps application servers"
  vpc_id      = aws_vpc.fieldops.id

  ingress {
    description     = "Application traffic from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fieldops-${var.environment}-app-sg"
  }
}

resource "aws_security_group" "database" {
  name        = "fieldops-${var.environment}-db-sg"
  description = "Security group for FieldOps PostgreSQL database"
  vpc_id      = aws_vpc.fieldops.id

  ingress {
    description     = "PostgreSQL from application tier"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.application.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fieldops-${var.environment}-db-sg"
  }
}