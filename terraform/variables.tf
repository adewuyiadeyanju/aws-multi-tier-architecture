variable "aws_region" {
  description = "AWS region where the FieldOps infrastructure will be deployed."
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the FieldOps VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "database_username" {
  description = "Master username for the FieldOps PostgreSQL database."
  type        = string
  default     = "fieldopsadmin"
}

variable "application_image_tag" {
  description = "Docker image tag to deploy for the FieldOps application."
  type        = string
  default     = "v1.0.0"
}

