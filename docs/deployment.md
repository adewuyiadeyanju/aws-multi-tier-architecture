# Deployment Guide

## 1. Overview

This document describes the deployment, validation, troubleshooting, and teardown process for the **AWS Multi-Tier Architecture** portfolio project.

The infrastructure is provisioned using **Terraform** and includes:

- Amazon VPC
- Public and private subnets
- Internet Gateway
- NAT Gateway
- Application Load Balancer (ALB)
- EC2 Auto Scaling Group
- EC2 Launch Template
- Docker
- Amazon ECR
- Amazon RDS PostgreSQL
- AWS Secrets Manager
- IAM roles and instance profiles
- AWS Systems Manager Session Manager
- Amazon S3 VPC endpoint
- FastAPI application

The application runs as a Docker container on Amazon Linux 2023 EC2 instances in private application subnets.

> **Portfolio cost-control note:** The environment was successfully deployed and validated end-to-end. After validation, the chargeable infrastructure was destroyed. The ECR repository and application image were retained so the application can be redeployed without rebuilding the image.

---

## 2. Deployment Architecture

The deployment follows this traffic flow:

```text
                         Internet
                            |
                            v
                  Application Load Balancer
                            |
                            v
                     Target Group :8080
                            |
                 +----------+----------+
                 |                     |
                 v                     v
          EC2 Application 1     EC2 Application 2
          Private Subnet        Private Subnet
                 |                     |
                 +----------+----------+
                            |
                            v
                      RDS PostgreSQL
                      Private Subnets
```

The EC2 application instances do not have public IP addresses.

Administrative access is provided through **AWS Systems Manager Session Manager**, avoiding the need for inbound SSH access.

---

## 3. Prerequisites

The following tools were used during development and deployment:

- Windows
- PowerShell
- AWS CLI
- Terraform
- Git
- Python virtual environment
- Docker
- AWS account with appropriate IAM permissions

The validated deployment used the AWS region:

```text
eu-west-1
```

### Verify AWS CLI

```powershell
aws --version
```

### Verify Terraform

```powershell
terraform version
```

### Verify AWS identity

```powershell
aws sts get-caller-identity
```

---

## 4. Repository Structure

The project is organized approximately as follows:

```text
aws-multi-tier-architecture/
|
+-- architecture/
|   +-- aws-multi-tier-architecture.png
|
+-- docs/
|   +-- architecture.md
|   +-- deployment.md
|   +-- validation.md
|   +-- troubleshooting.md
|
+-- terraform/
|   +-- providers.tf
|   +-- variables.tf
|   +-- outputs.tf
|   +-- networking.tf
|   +-- security.tf
|   +-- iam.tf
|   +-- compute.tf
|   +-- alb.tf
|   +-- database.tf
|   +-- ecr.tf
|   +-- ...
|
+-- application/
|   +-- FastAPI application
|
+-- Dockerfile
+-- README.md
+-- LICENSE
```

Terraform is the source of truth for the AWS infrastructure.

---

# 5. Terraform Deployment

## 5.1 Navigate to the Terraform Directory

From PowerShell:

```powershell
cd C:\Users\User\Documents\aws-multi-tier-architecture\terraform
```

Activate the Python virtual environment if required:

```powershell
.venv\Scripts\Activate.ps1
```

## 5.2 Initialize Terraform

```powershell
terraform init
```

This initializes the Terraform working directory and downloads the required providers.

## 5.3 Review the Terraform Plan

Before creating infrastructure:

```powershell
terraform plan
```

Review the plan carefully before applying changes.

The deployment creates the networking, security, compute, database, load balancing, IAM, and supporting resources defined by the Terraform configuration.

## 5.4 Apply the Infrastructure

```powershell
terraform apply
```

Review the proposed changes and confirm the deployment when prompted.

After a successful deployment, Terraform provides outputs such as:

- VPC ID
- ALB DNS name
- Target group ARN
- Auto Scaling Group name
- Security group IDs
- RDS endpoint
- Secrets Manager ARN
- ECR repository URL

> Resource IDs, DNS names, and endpoints may change on subsequent deployments. Do not hard-code them in application code or documentation unless clearly identified as historical validation values.

---

# 6. Amazon ECR Container Image

The application is packaged as a Docker image and stored in Amazon ECR.

The validated repository was:

```text
fieldops-dev
```

The validated application image tag was:

```text
v1.0.0
```

### 6.1 Authenticate to ECR

```powershell
aws ecr get-login-password --region eu-west-1 |
docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.eu-west-1.amazonaws.com
```

### 6.2 Build the Application Image

From the application/project directory:

```powershell
docker build -t fieldops-dev:v1.0.0 .
```

### 6.3 Tag the Image

```powershell
docker tag fieldops-dev:v1.0.0 `
  <ACCOUNT_ID>.dkr.ecr.eu-west-1.amazonaws.com/fieldops-dev:v1.0.0
```

### 6.4 Push the Image

```powershell
docker push `
  <ACCOUNT_ID>.dkr.ecr.eu-west-1.amazonaws.com/fieldops-dev:v1.0.0
```

### 6.5 Verify the Image

```powershell
aws ecr describe-images `
  --repository-name fieldops-dev `
  --region eu-west-1
```

The validated deployment successfully pulled the `v1.0.0` image from ECR.

---

# 7. EC2 Application Tier

The application tier is managed by an **EC2 Auto Scaling Group**.

The validated configuration used two application instances distributed across multiple Availability Zones.

Each instance runs:

- Amazon Linux 2023
- Docker
- FastAPI
- Uvicorn

The application listens on:

```text
TCP 8080
```

The instances are deployed into private application subnets.

---

# 8. EC2 Bootstrap Process

The EC2 Launch Template uses user data to bootstrap new instances.

The validated bootstrap process:

1. Updates the operating system.
2. Installs Docker and `jq`.
3. Verifies that `curl` is available.
4. Starts Docker.
5. Verifies that Docker is running.
6. Retrieves application configuration.
7. Authenticates with Amazon ECR.
8. Pulls the application image.
9. Retrieves database credentials from AWS Secrets Manager.
10. Creates the runtime database environment file.
11. Starts the FastAPI Docker container.

The bootstrap log is written to:

```text
/var/log/fieldops-user-data.log
```

Check cloud-init status:

```bash
sudo cloud-init status --long
```

A successful bootstrap reports:

```text
status: done
```

> **AMI note:** `curl` was already available in the Amazon Linux 2023 AMI used during validation. The bootstrap therefore verifies its availability rather than depending on a separate curl installation step.

---

# 9. Docker Verification

After connecting to an EC2 instance through Session Manager:

```bash
docker --version
```

Verify the Docker service:

```bash
sudo systemctl status docker --no-pager
```

The expected state is:

```text
Active: active (running)
```

The validated environment used Docker 25.x on Amazon Linux 2023.

---

# 10. AWS Systems Manager Access

The application instances are accessed using **AWS Systems Manager Session Manager** rather than SSH.

Example:

```powershell
aws ssm start-session `
  --target <INSTANCE-ID> `
  --region eu-west-1
```

Session Manager provides administrative access without exposing SSH to the Internet.

---

# 11. ECR Authentication on EC2

When manually testing ECR access from an EC2 instance, the Docker credentials must belong to the same user context that executes the Docker command.

During validation, the following sequence was attempted:

```bash
aws ecr get-login-password --region eu-west-1 |
docker login --username AWS --password-stdin \
<ACCOUNT_ID>.dkr.ecr.eu-west-1.amazonaws.com
```

followed by:

```bash
sudo docker pull <ECR-IMAGE>
```

This failed with:

```text
no basic auth credentials
```

The reason was that the ECR credentials were stored in the non-root user's Docker configuration, while `sudo docker` uses the root user's Docker configuration.

The validated solution was:

```bash
aws ecr get-login-password --region eu-west-1 |
sudo docker login --username AWS --password-stdin \
<ACCOUNT_ID>.dkr.ecr.eu-west-1.amazonaws.com
```

Then:

```bash
sudo docker pull \
<ACCOUNT_ID>.dkr.ecr.eu-west-1.amazonaws.com/fieldops-dev:v1.0.0
```

The image was successfully downloaded using this approach.

---

# 12. Database Configuration

The application uses **Amazon RDS PostgreSQL**.

The validated database configuration used:

```text
Port: 5432
Database: fieldops
```

The database is deployed in private database subnets and is not directly accessible from the Internet.

The application tier accesses the database through the appropriate security-group rules.

---

# 13. AWS Secrets Manager

Database credentials are stored in **AWS Secrets Manager**.

The RDS-generated secret used during validation contained the database username and password.

Example structure:

```json
{
  "username": "...",
  "password": "..."
}
```

The secret did not contain all of the application connection parameters required by the application.

Therefore, the runtime configuration was constructed from:

- RDS endpoint
- Database port
- Database name
- Secrets Manager username
- Secrets Manager password

The resulting environment variables were:

```text
DATABASE_HOST=<RDS-ENDPOINT>
DATABASE_PORT=5432
DATABASE_NAME=fieldops
DATABASE_USERNAME=<RETRIEVED-FROM-SECRETS-MANAGER>
DATABASE_PASSWORD=<RETRIEVED-FROM-SECRETS-MANAGER>
```

The runtime environment file was:

```text
/run/fieldops/database.env
```

It was protected with:

```bash
sudo chmod 600 /run/fieldops/database.env
```

> Database passwords must never be committed to Git, placed in Terraform source files, or exposed in documentation.

---

# 14. Application Container

The validated deployment started the application container with:

```bash
sudo docker run -d \
  --name fieldops-api \
  --restart unless-stopped \
  --env-file /run/fieldops/database.env \
  -p 8080:8080 \
  <ACCOUNT_ID>.dkr.ecr.eu-west-1.amazonaws.com/fieldops-dev:v1.0.0
```

Verify the container:

```bash
sudo docker ps
```

The expected container name is:

```text
fieldops-api
```

with port mapping:

```text
0.0.0.0:8080->8080/tcp
```

---

# 15. Application Logs

Inspect the application logs with:

```bash
sudo docker logs fieldops-api
```

The validated application produced:

```text
INFO:     Started server process [1]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8080
```

This confirms that the FastAPI application started successfully.

For recent logs:

```bash
sudo docker logs fieldops-api --tail 50
```

---

# 16. Local Application Health Check

From the EC2 instance:

```bash
curl -i http://127.0.0.1:8080/health
```

The validated response was:

```http
HTTP/1.1 200 OK
```

with:

```json
{
  "status": "healthy"
}
```

This validates the local path:

```text
EC2
 |
 v
Docker
 |
 v
FastAPI
```

---

# 17. Application Load Balancer

The **Application Load Balancer** provides the public application entry point.

The ALB forwards traffic to the target group on:

```text
Port 8080
```

The target group performs health checks against:

```text
/health
```

Check the ALB:

```powershell
aws elbv2 describe-load-balancers `
  --names fieldops-dev-alb `
  --region eu-west-1 `
  --query "LoadBalancers[0].[State.Code,DNSName]" `
  --output table
```

A successfully deployed ALB should report:

```text
active
```

---

# 18. Target Group Validation

Retrieve the target group ARN:

```powershell
terraform output -raw application_target_group_arn
```

Check target health:

```powershell
aws elbv2 describe-target-health `
  --target-group-arn "$(terraform output -raw application_target_group_arn)" `
  --region eu-west-1
```

The final validated deployment reported both application instances as:

```text
State: healthy
```

The target group was configured for port `8080`.

---

# 19. End-to-End Application Validation

Retrieve the ALB DNS name:

```powershell
terraform output -raw alb_dns_name
```

Test the root endpoint:

```powershell
curl.exe http://<ALB-DNS-NAME>/
```

The validated application returned:

```json
{
  "application": "FieldOps API",
  "version": "1.0.0",
  "environment": "development",
  "status": "running"
}
```

This confirms that the application was reachable through the public ALB.

---

# 20. Application Health Validation

Test:

```powershell
curl.exe http://<ALB-DNS-NAME>/health
```

Expected response:

```json
{
  "status": "healthy"
}
```

This validates:

```text
Internet
   |
   v
Application Load Balancer
   |
   v
Target Group
   |
   v
EC2
   |
   v
Docker
   |
   v
FastAPI
```

---

# 21. Database Connectivity Validation

The application provides a dedicated database health endpoint:

```text
/health/database
```

Test:

```powershell
curl.exe http://<ALB-DNS-NAME>/health/database
```

The validated response was:

```json
{
  "status": "healthy",
  "database": "connected"
}
```

The endpoint performs a non-destructive:

```sql
SELECT 1
```

against PostgreSQL.

This validated the complete application-to-database path:

```text
Internet
   |
   v
Application Load Balancer
   |
   v
EC2
   |
   v
Docker
   |
   v
FastAPI
   |
   v
SQLAlchemy
   |
   v
RDS PostgreSQL
```

---

# 22. Auto Scaling Group Validation

Inspect the Auto Scaling Group:

```powershell
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names fieldops-dev-asg `
  --region eu-west-1 `
  --query "AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]" `
  --output table
```

The final validated environment contained two application instances reporting:

```text
InService    Healthy
InService    Healthy
```

---

# 23. Instance Refresh

An EC2 Auto Scaling instance refresh was performed during deployment testing to ensure that instances were replaced using the current Launch Template configuration.

Start an instance refresh:

```powershell
aws autoscaling start-instance-refresh `
  --auto-scaling-group-name fieldops-dev-asg `
  --preferences MinHealthyPercentage=50,InstanceWarmup=120 `
  --region eu-west-1
```

Monitor the refresh:

```powershell
aws autoscaling describe-instance-refreshes `
  --auto-scaling-group-name fieldops-dev-asg `
  --region eu-west-1 `
  --query "InstanceRefreshes[0].[Status,PercentageComplete,InstancesToUpdate,InstancesUpdated]" `
  --output table
```

During validation, the refresh reached:

```text
PercentageComplete: 100
```

After replacement, the Auto Scaling Group contained two healthy instances and both ALB targets ultimately reported healthy.

---

# 24. Recommended Validation Sequence

The recommended validation sequence is:

```text
1. Terraform infrastructure
          |
          v
2. Auto Scaling Group
          |
          v
3. EC2 instances
          |
          v
4. Docker
          |
          v
5. ECR image
          |
          v
6. Application container
          |
          v
7. ALB target health
          |
          v
8. Application health
          |
          v
9. Database connectivity
```

This sequence isolates failures by infrastructure layer.

---

# 25. Operational Validation Commands

## Check EC2 Instances

```powershell
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names fieldops-dev-asg `
  --region eu-west-1 `
  --query "AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]" `
  --output table
```

## Check ALB

```powershell
aws elbv2 describe-load-balancers `
  --names fieldops-dev-alb `
  --region eu-west-1 `
  --query "LoadBalancers[0].[State.Code,DNSName]" `
  --output table
```

## Check Target Health

```powershell
aws elbv2 describe-target-health `
  --target-group-arn "$(terraform output -raw application_target_group_arn)" `
  --region eu-west-1
```

## Test Application

```powershell
curl.exe http://<ALB-DNS-NAME>/
```

## Test Application Health

```powershell
curl.exe http://<ALB-DNS-NAME>/health
```

## Test Database Connectivity

```powershell
curl.exe http://<ALB-DNS-NAME>/health/database
```

## Connect to an EC2 Instance

```powershell
aws ssm start-session `
  --target <INSTANCE-ID> `
  --region eu-west-1
```

## Check Docker

```bash
sudo systemctl status docker --no-pager
```

## Check Application Container

```bash
sudo docker ps
```

## Check Application Logs

```bash
sudo docker logs fieldops-api --tail 50
```

---

# 26. Troubleshooting Lessons

Several issues were encountered during deployment and resolved successfully.

## 26.1 Terraform Was Not Available on EC2

Terraform commands are executed from the local development environment.

An attempt to run:

```bash
terraform output
```

from an EC2 Session Manager shell failed because Terraform was not installed on the instance.

The correct approach is to run Terraform commands from the Terraform project directory on the development machine.

---

## 26.2 Docker Permission Error

Running:

```bash
docker pull <ECR-IMAGE>
```

as the SSM user resulted in:

```text
permission denied while trying to connect to the Docker daemon socket
```

The Docker daemon was running, but the current user did not have permission to access the Docker socket.

Using:

```bash
sudo docker pull <ECR-IMAGE>
```

allowed access to the Docker daemon.

---

## 26.3 ECR Authentication Context

A subsequent pull using `sudo docker` initially failed with:

```text
no basic auth credentials
```

The reason was that ECR credentials had been stored in the non-root user's Docker configuration while Docker was being executed with `sudo`.

The validated solution was:

```bash
aws ecr get-login-password --region eu-west-1 |
sudo docker login --username AWS --password-stdin \
<ACCOUNT_ID>.dkr.ecr.eu-west-1.amazonaws.com
```

followed by:

```bash
sudo docker pull \
<ACCOUNT_ID>.dkr.ecr.eu-west-1.amazonaws.com/fieldops-dev:v1.0.0
```

---

## 26.4 RDS Secret Structure

The RDS-generated Secrets Manager secret contained:

```json
{
  "username": "...",
  "password": "..."
}
```

It did not contain all of the application connection parameters.

Attempting to extract unavailable fields resulted in values such as:

```text
DATABASE_HOST=null
DATABASE_PORT=null
DATABASE_NAME=null
```

The application configuration was therefore corrected by combining:

- RDS endpoint
- Database port
- Database name
- Secrets Manager username
- Secrets Manager password

into the runtime environment file.

---

## 26.5 ALB Target Health

During the first instance refresh, one application instance reported:

```text
Target.FailedHealthChecks
```

The application container and health endpoint were inspected.

The affected instance was subsequently replaced through the Auto Scaling Group instance refresh.

The final environment reported:

```text
InService / Healthy
InService / Healthy
```

and both ALB targets ultimately reported:

```text
State: healthy
```

---

# 27. Infrastructure Destruction

Because this is a portfolio project and the environment incurs ongoing AWS charges, the deployed infrastructure was intentionally destroyed after successful validation.

From the Terraform directory:

```powershell
terraform destroy
```

Review the resources carefully before confirming destruction.

Depending on the Terraform configuration, this can remove resources such as:

- VPC
- Subnets
- NAT Gateway
- Application Load Balancer
- Target Group
- EC2 Auto Scaling Group
- EC2 instances
- RDS PostgreSQL
- Security groups
- IAM resources managed by Terraform
- VPC endpoints

The exact resources removed depend on the Terraform configuration and lifecycle settings.

> Always review `terraform plan` and the Terraform state before destructive operations.

---

# 28. Cost Management

Cost management is an explicit consideration of this portfolio project.

The infrastructure was intentionally destroyed after successful validation rather than leaving chargeable resources running continuously.

Particular attention should be given to:

- NAT Gateway hourly charges
- NAT Gateway data processing
- Application Load Balancer
- EC2 instances
- RDS PostgreSQL
- Storage
- Data transfer

The ECR repository and application image were retained so the application can be redeployed without rebuilding the container image.

Before destroying or recreating infrastructure, review:

```powershell
terraform plan
```

After destruction, Terraform outputs for resources that no longer exist may no longer be available.

---

# 29. Redeployment

The architecture can be redeployed from the Terraform configuration.

High-level process:

```text
terraform init
      |
      v
terraform plan
      |
      v
terraform apply
      |
      v
Verify EC2 instances
      |
      v
Verify Docker bootstrap
      |
      v
Verify ECR image
      |
      v
Verify ALB target health
      |
      v
Test /health
      |
      v
Test /health/database
```

Because the ECR image was retained, the redeployment can reuse:

```text
fieldops-dev:v1.0.0
```

provided that the Terraform configuration continues to reference the same repository and image tag.

---

# 30. Deployment Success Criteria

A deployment is considered successful when the following conditions are satisfied:

- Terraform apply completes successfully.
- VPC and subnet architecture is available.
- Auto Scaling Group launches application instances.
- EC2 instances report `InService`.
- EC2 instances report `Healthy`.
- Docker is installed and running.
- The application container is running.
- The ECR image is successfully pulled.
- The ALB is active.
- The ALB target group reports healthy targets.
- `/` returns the application response.
- `/health` returns HTTP 200.
- `/health/database` reports database connectivity.
- RDS PostgreSQL is reachable from the application tier.
- Administrative access through Session Manager works.

---

# 31. Final Validated Deployment

The final deployment demonstrated:

```text
                         Internet
                            |
                            v
                  Application Load Balancer
                            |
                            v
                     Target Group :8080
                            |
                 +----------+----------+
                 |                     |
                 v                     v
          EC2 Application 1     EC2 Application 2
          Private Subnet        Private Subnet
                 |                     |
                 v                     v
              Docker                Docker
                 |                     |
                 v                     v
              FastAPI               FastAPI
                 |                     |
                 +----------+----------+
                            |
                            v
                      RDS PostgreSQL
                      Private Subnets
```

The final end-to-end validation confirmed the application path:

```text
ALB
 |
 v
EC2
 |
 v
Docker
 |
 v
FastAPI
 |
 v
SQLAlchemy
 |
 v
RDS PostgreSQL
```

Successful responses were obtained from:

```text
/health
```

and:

```text
/health/database
```

The infrastructure was subsequently destroyed after validation to control project costs.

---

# 32. Related Documentation

Additional project documentation:

- [`README.md`](../README.md) — project overview, architecture, implementation status, and roadmap
- [`architecture.md`](architecture.md) — architecture, AWS services, network segmentation, and traffic flow
- [`validation.md`](validation.md) — detailed validation procedures and results
- [`troubleshooting.md`](troubleshooting.md) — deployment and runtime troubleshooting
