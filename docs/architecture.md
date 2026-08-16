# FieldOps AWS Multi-Tier Architecture

## 1. Architecture Overview

The proposed solution is a highly available, secure and scalable multi-tier AWS architecture designed to modernize the FieldOps operations application.

The architecture separates the application into distinct network and workload tiers and distributes application workloads across two AWS Availability Zones.

The solution uses managed AWS services where appropriate to reduce operational overhead while maintaining control over the application and infrastructure layers.

### High-Level Architecture

```text
                           INTERNET
                               │
                               ▼
                          Route 53
                               │
                               ▼
                        HTTPS / ACM
                               │
                               ▼
                  ┌───────────────────────┐
                  │ Application Load      │
                  │      Balancer         │
                  └───────────┬───────────┘
                              │
                 ┌────────────┴────────────┐
                 │                         │
                 ▼                         ▼
          ┌─────────────┐           ┌─────────────┐
          │    AZ-1     │           │    AZ-2     │
          │             │           │             │
          │ EC2 Instance│           │ EC2 Instance│
          │ Application │           │ Application │
          └──────┬──────┘           └──────┬──────┘
                 │                         │
                 └────────────┬────────────┘
                              │
                              ▼
                       ┌─────────────┐
                       │     RDS     │
                       │ PostgreSQL  │
                       └─────────────┘

                              │
                              ▼
                       ┌─────────────┐
                       │     S3      │
                       │ Object      │
                       │ Storage     │
                       └─────────────┘

                 ┌─────────────────────────┐
                 │       CloudWatch        │
                 │ Metrics | Logs | Alarms │
                 └─────────────────────────┘
```

---

# 2. AWS Architecture Components

## 2.1 Amazon VPC

A dedicated Amazon VPC provides the network boundary for the application.

The VPC will use multiple Availability Zones to improve resilience.

The network will contain separate subnet tiers for:

* Public infrastructure
* Application workloads
* Database workloads

The architecture will use route tables and network controls to restrict communication between tiers.

---

## 2.2 Availability Zones

The solution will span two Availability Zones within a single AWS Region.

Application workloads will be distributed across both Availability Zones.

This reduces dependency on a single Availability Zone and improves application resilience.

---

## 2.3 Public Subnets

Public subnets will contain resources that require controlled internet connectivity.

The primary public-facing component will be the Application Load Balancer.

Public subnets will have routes through the Internet Gateway.

Application and database workloads will not be directly exposed to the public internet.

---

## 2.4 Private Application Subnets

Application workloads will run in private subnets.

EC2 instances will not have public IP addresses.

The application tier will receive traffic only from the Application Load Balancer.

Outbound internet access required by application instances will be provided through controlled network egress.

---

## 2.5 Private Database Subnets

Amazon RDS PostgreSQL will run in private database subnets.

The database will not have a public IP address.

Database access will be restricted to the application tier using security-group rules.

---

# 3. Application Load Balancer

An Application Load Balancer will provide the public entry point for the application.

Responsibilities include:

* HTTPS termination
* Request distribution
* Health checks
* Routing traffic to healthy application instances
* Supporting horizontal application scaling

The ALB will be deployed across multiple Availability Zones.

Only the ALB will accept public application traffic.

---

# 4. EC2 Application Tier

The application will run on Amazon EC2 instances managed through an Auto Scaling Group.

The application tier will span two Availability Zones.

The Auto Scaling Group will provide:

* Horizontal scaling
* Instance health monitoring
* Automatic replacement of unhealthy instances
* Capacity management

EC2 instances will use IAM instance roles rather than embedding AWS access credentials in the application or operating system.

---

# 5. Amazon RDS PostgreSQL

Amazon RDS for PostgreSQL will provide relational database services for the application.

RDS is selected instead of self-managed PostgreSQL on EC2 to reduce operational overhead associated with:

* Database patching
* Backups
* Maintenance
* Monitoring
* Failover management

The database will be deployed using private networking.

The application security group will be granted access to the database security group on the PostgreSQL port.

No direct internet access to the database will be permitted.

---

# 6. Amazon S3

Amazon S3 will provide durable object storage for:

* Application documents
* Uploaded files
* Static assets where appropriate
* Application artifacts
* Other non-relational objects

The S3 bucket will use appropriate security controls and encryption.

Public access will be blocked unless a specific business requirement requires otherwise.

---

# 7. Identity and Access Management

AWS IAM will control access to AWS resources.

The architecture will follow the principle of least privilege.

Where workloads require AWS API access, IAM roles will be preferred over long-lived access keys.

IAM permissions will be separated according to workload and operational responsibility.

---

# 8. Security Architecture

Security will be implemented using multiple layers of controls.

### Network Security

* VPC network isolation
* Public/private subnet separation
* Security Groups
* Controlled routing
* Private database networking

### Identity Security

* IAM roles
* Least-privilege permissions
* Separation of administrative and workload access

### Data Security

* Encryption at rest
* Encryption in transit
* Secure database connectivity
* S3 Block Public Access

### Application Security

* HTTPS
* Load-balancer health checks
* Restricted application access
* Restricted database access

---

# 9. Monitoring and Observability

Amazon CloudWatch will provide centralized monitoring.

The solution will monitor:

* EC2 instance health
* CPU utilization
* Application Load Balancer metrics
* Request counts
* Target health
* Database metrics
* Application logs
* Infrastructure alarms

CloudWatch alarms will be used to identify significant infrastructure conditions requiring attention.

---

# 10. Infrastructure as Code

Infrastructure will be provisioned using Terraform.

Terraform will manage infrastructure including:

* VPC
* Subnets
* Route tables
* Internet Gateway
* NAT Gateway
* Security Groups
* IAM roles
* Application Load Balancer
* EC2 resources
* Auto Scaling
* RDS
* S3
* CloudWatch resources

The objective is to make the environment reproducible and version controlled.

---

# 11. Deployment Architecture

The application and infrastructure will use a Git-based development workflow.

The intended deployment flow is:

```text
Developer
    │
    ▼
Git Repository
    │
    ▼
CI/CD Pipeline
    │
    ├── Application Tests
    │
    ├── Terraform Validation
    │
    ├── Terraform Plan
    │
    └── Deployment
            │
            ▼
        AWS Environment
```

CI/CD implementation will be introduced after the initial infrastructure is operational.

---

# 12. Key Architecture Decisions

## Decision 1 — EC2 instead of ECS

EC2 is selected for the initial application architecture.

Reasons:

* Demonstrates operating-system-level cloud infrastructure.
* Provides direct exposure to EC2 networking and IAM.
* Demonstrates Auto Scaling.
* Demonstrates load balancing.
* Aligns directly with the AWS Solutions Architect role requirements.
* Builds on existing Linux and infrastructure experience.

Containerization and ECS will be considered as a future modernization step.

---

## Decision 2 — RDS instead of self-managed PostgreSQL

Amazon RDS is selected to reduce database operational overhead.

The managed service provides capabilities for backups, maintenance and high availability while allowing the architecture to retain a relational database model.

---

## Decision 3 — Multi-AZ architecture

Application workloads will span two Availability Zones.

This reduces the impact of a single Availability Zone failure and provides a foundation for high availability.

---

## Decision 4 — Private application and database tiers

Application and database workloads will not be directly exposed to the internet.

Only the Application Load Balancer will be internet-facing.

This reduces the external attack surface and provides clear network security boundaries.

---

## Decision 5 — Terraform

Terraform will be used as the Infrastructure-as-Code platform.

This provides:

* Version-controlled infrastructure
* Repeatable deployments
* Infrastructure consistency
* Reviewable changes
* Automated provisioning
* Reproducibility

---

# 13. Architecture Goals

The architecture is designed around the following priorities:

1. Security
2. Reliability
3. Scalability
4. Operational Excellence
5. Performance Efficiency
6. Cost Optimization

These priorities will be evaluated formally against the AWS Well-Architected Framework after the initial implementation.

---

# 14. Future Architecture Evolution

Future versions of the platform may evaluate:

* Amazon ECS
* AWS Fargate
* Amazon CloudFront
* AWS WAF
* Amazon ElastiCache
* AWS Lambda
* Amazon API Gateway
* Multi-region disaster recovery
* Advanced observability
* Automated security controls
* Serverless components

These services are intentionally not included in the initial architecture unless justified by a specific requirement.
