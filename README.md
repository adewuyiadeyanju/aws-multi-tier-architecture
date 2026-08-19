# AWS Multi-Tier Architecture

A production-oriented multi-tier AWS architecture demonstrating scalable, secure, resilient, and cost-conscious cloud infrastructure using Terraform.

## Project Status

🟢 **Core infrastructure deployed and validated**

The current implementation successfully provisions and validates the core AWS application stack, including networking, load balancing, compute, container deployment, and PostgreSQL database connectivity.

## Architecture

The solution follows a multi-tier architecture:

```text
                         Internet
                            │
                            ▼
                  Application Load Balancer
                            │
                     Target Group :8080
                            │
                 ┌──────────┴──────────┐
                 ▼                     ▼
          EC2 Application 1     EC2 Application 2
                 │                     │
                 └──────────┬──────────┘
                            │
                       Docker / FastAPI
                            │
                            ▼
                     RDS PostgreSQL
```

### AWS Components

* Amazon VPC
* Public and private subnets
* Internet Gateway
* NAT Gateway
* Application Load Balancer
* Application Load Balancer target group
* EC2 Auto Scaling Group
* EC2 Launch Template
* Docker
* Amazon ECR
* Amazon RDS PostgreSQL
* AWS Secrets Manager
* IAM roles and instance profiles
* Amazon S3 VPC endpoint
* AWS Systems Manager Session Manager

## Objectives

* Design a highly available AWS multi-tier application
* Apply AWS Well-Architected Framework principles
* Implement infrastructure using Terraform
* Apply security and least-privilege principles
* Demonstrate scalability and resilience
* Implement containerized application deployment
* Implement monitoring and observability
* Evaluate architecture cost and optimization opportunities

## Current Implementation

### Networking

The environment uses a VPC with:

* Public subnets for internet-facing resources
* Private application subnets for EC2 workloads
* Private database subnets for PostgreSQL
* Internet Gateway for public connectivity
* NAT Gateway for controlled outbound connectivity from private resources
* S3 VPC endpoint for private S3 access

### Application Tier

The application tier consists of an Auto Scaling Group with two EC2 instances.

Each instance:

1. Runs Amazon Linux 2023
2. Installs and starts Docker
3. Authenticates to Amazon ECR
4. Pulls the FieldOps API container image
5. Retrieves database credentials from AWS Secrets Manager
6. Starts the FastAPI application container
7. Exposes the application on port `8080`

### Load Balancing

The Application Load Balancer distributes traffic across the application instances.

The target group performs health checks against:

```text
/health
```

on port:

```text
8080
```

Both application instances have been successfully validated as healthy targets.

### Database

The application uses Amazon RDS PostgreSQL in private database subnets.

Database credentials are stored in AWS Secrets Manager.

The application validates database connectivity through:

```text
/health/database
```

which executes a non-destructive database connectivity test.

## Validation Results

The deployed environment has been successfully validated end-to-end.

| Component                   | Status                      |
| --------------------------- | --------------------------- |
| VPC                         | ✅ Deployed                  |
| Public subnets              | ✅ Deployed                  |
| Private application subnets | ✅ Deployed                  |
| Private database subnets    | ✅ Deployed                  |
| Application Load Balancer   | ✅ Active                    |
| Target Group                | ✅ Healthy                   |
| Application Instance 1      | ✅ InService / Healthy       |
| Application Instance 2      | ✅ InService / Healthy       |
| Docker                      | ✅ Running                   |
| Amazon ECR                  | ✅ Image successfully pulled |
| FastAPI application         | ✅ Running                   |
| `/health`                   | ✅ Healthy                   |
| `/health/database`          | ✅ Database connected        |
| RDS PostgreSQL              | ✅ Connectivity validated    |
| AWS Systems Manager         | ✅ Instances accessible      |

### End-to-End Validation

The application was successfully accessed through the public Application Load Balancer.

The application health endpoint returned:

```json
{
  "status": "healthy"
}
```

The database health endpoint returned:

```json
{
  "status": "healthy",
  "database": "connected"
}
```

This confirms connectivity across the complete application path:

```text
Internet
   ↓
Application Load Balancer
   ↓
Target Group
   ↓
EC2
   ↓
Docker
   ↓
FastAPI
   ↓
SQLAlchemy
   ↓
RDS PostgreSQL
```

## Infrastructure as Code

Infrastructure is provisioned using Terraform.

The Terraform configuration is organized into reusable infrastructure components covering:

* Networking
* Security groups
* IAM
* Load balancing
* Compute
* Database
* Container registry
* VPC endpoints
* Environment configuration

Terraform is the source of truth for the deployed infrastructure.

## Security

The architecture applies several security principles:

* Application instances are deployed in private subnets
* Database instances are isolated in database subnets
* IAM roles are used instead of static AWS credentials
* Database credentials are stored in AWS Secrets Manager
* AWS Systems Manager Session Manager is used for administrative access
* Security groups restrict communication between tiers
* IMDSv2 is required on EC2 instances
* Database access is restricted to the application tier

## Deployment

The infrastructure can be deployed from the Terraform directory using:

```powershell
terraform init
terraform plan
terraform apply
```

Before applying changes, always review the Terraform plan carefully.

## Validation Commands

Check Auto Scaling Group instances:

```powershell
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names fieldops-dev-asg `
  --region eu-west-1
```

Check target health:

```powershell
aws elbv2 describe-target-health `
  --target-group-arn "$(terraform output -raw application_target_group_arn)" `
  --region eu-west-1
```

Test the application through the ALB:

```powershell
curl.exe http://<ALB-DNS-NAME>/
```

Test application health:

```powershell
curl.exe http://<ALB-DNS-NAME>/health
```

Test database connectivity:

```powershell
curl.exe http://<ALB-DNS-NAME>/health/database
```

## Project Roadmap

### Completed

* [x] AWS VPC and subnet architecture
* [x] Public and private networking
* [x] Application Load Balancer
* [x] Auto Scaling Group
* [x] EC2 application instances
* [x] Docker-based application deployment
* [x] Amazon ECR integration
* [x] RDS PostgreSQL
* [x] Secrets Manager integration
* [x] IAM instance role
* [x] Systems Manager access
* [x] ALB health checks
* [x] End-to-end application validation
* [x] Database connectivity validation

### Next

* [ ] CloudWatch monitoring and dashboards
* [ ] Application and infrastructure alarms
* [ ] Centralized logging
* [ ] CI/CD pipeline
* [ ] Automated image deployment
* [ ] HTTPS/TLS with ACM
* [ ] Route 53 integration
* [ ] Backup and disaster recovery validation
* [ ] Cost analysis and optimization
* [ ] Security hardening review
* [ ] Load and resilience testing

## Documentation

Detailed documentation is available in the `docs/` directory:

* `architecture.md` — architecture and AWS component design
* `deployment.md` — deployment and operational procedures
* `validation.md` — infrastructure and application validation
* `troubleshooting.md` — common deployment and runtime issues

## License

See [LICENSE](LICENSE).
