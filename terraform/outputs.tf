output "vpc_id" {
  description = "ID of the FieldOps VPC."
  value       = aws_vpc.fieldops.id
}

output "vpc_cidr" {
  description = "CIDR block of the FieldOps VPC."
  value       = aws_vpc.fieldops.cidr_block
}

output "availability_zones" {
  description = "Availability Zones used by the FieldOps VPC."
  value       = data.aws_availability_zones.available.names
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = aws_subnet.public[*].id
}

output "application_subnet_ids" {
  description = "Private application subnet IDs."
  value       = aws_subnet.application[*].id
}

output "database_subnet_ids" {
  description = "Private database subnet IDs."
  value       = aws_subnet.database[*].id
}

output "internet_gateway_id" {
  description = "ID of the FieldOps Internet Gateway."
  value       = aws_internet_gateway.fieldops.id
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID."
  value       = aws_nat_gateway.fieldops.id
}

output "application_route_table_ids" {
  description = "Private application route table IDs."
  value       = aws_route_table.application[*].id
}

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 VPC Gateway Endpoint."
  value       = aws_vpc_endpoint.s3.id
}

output "alb_security_group_id" {
  description = "Security group ID for the Application Load Balancer."
  value       = aws_security_group.alb.id
}

output "application_security_group_id" {
  description = "Security group ID for the application tier."
  value       = aws_security_group.application.id
}

output "database_security_group_id" {
  description = "Security group ID for the database tier."
  value       = aws_security_group.database.id
}

output "alb_dns_name" {
  description = "DNS name of the FieldOps Application Load Balancer."
  value       = aws_lb.fieldops.dns_name
}

output "alb_arn" {
  description = "ARN of the FieldOps Application Load Balancer."
  value       = aws_lb.fieldops.arn
}

output "application_target_group_arn" {
  description = "ARN of the application target group."
  value       = aws_lb_target_group.application.arn
}

output "application_iam_role_arn" {
  description = "ARN of the application EC2 IAM role."
  value       = aws_iam_role.application.arn
}

output "application_instance_profile_name" {
  description = "Name of the EC2 application instance profile."
  value       = aws_iam_instance_profile.application.name
}

output "application_launch_template_id" {
  description = "ID of the application Launch Template."
  value       = aws_launch_template.application.id
}

output "application_autoscaling_group_name" {
  description = "Name of the application Auto Scaling Group."
  value       = aws_autoscaling_group.application.name
}