resource "aws_db_subnet_group" "fieldops" {
  name = "fieldops-${var.environment}-db-subnet-group"

  subnet_ids = aws_subnet.database[*].id

  tags = {
    Name = "fieldops-${var.environment}-db-subnet-group"
  }
}

resource "aws_db_instance" "fieldops" {
  identifier = "fieldops-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = "17"

  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"

  db_name = "fieldops"
  port    = 5432

  username                    = var.database_username
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.fieldops.name
  vpc_security_group_ids = [aws_security_group.database.id]

  multi_az = true

  publicly_accessible = false

  storage_encrypted = true

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  auto_minor_version_upgrade = true

  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Name = "fieldops-${var.environment}-postgres"
  }
}