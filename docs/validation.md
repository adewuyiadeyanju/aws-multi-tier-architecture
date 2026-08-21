# Validation

## 1. Overview

This document records the validation performed against the AWS multi-tier application architecture.

The objective was to verify that the deployed infrastructure was operational end-to-end and that the major application, networking, compute, load balancing, container, and database components were functioning as designed.

The validated deployment was performed in:

```text
AWS Region: eu-west-1
```

The validation covered:

- VPC and subnet architecture
- EC2 Auto Scaling Group
- EC2 instance health
- Docker runtime
- Amazon ECR container image
- FastAPI application
- Application Load Balancer
- ALB target group health
- Application health endpoint
- RDS PostgreSQL connectivity
- AWS Systems Manager access
- End-to-end application traffic flow

---

## 2. Validation Strategy

Validation was performed progressively from the infrastructure layer toward the application layer.

The validation sequence was:

```text
AWS Infrastructure
       |
       v
Auto Scaling Group
       |
       v
EC2 Instances
       |
       v
Docker Runtime
       |
       v
Container
       |
       v
FastAPI Application
       |
       v
ALB Target Group
       |
       v
Application Load Balancer
       |
       v
Application Health
       |
       v
RDS PostgreSQL Connectivity
```

This approach allowed infrastructure, application, and database issues to be isolated during deployment.

---

# 3. Auto Scaling Group Validation

The application tier is managed by the following Auto Scaling Group:

```text
fieldops-dev-asg
```

The Auto Scaling Group was configured to maintain two application instances.

Validation was performed using:

```powershell
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names fieldops-dev-asg `
  --region eu-west-1 `
  --query "AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]" `
  --output table
```

The final validated state showed:

```text
-------------------------------------------------
|           DescribeAutoScalingGroups           |
+----------------------+-------------+----------+
| Instance ID          | State       | Health   |
+----------------------+-------------+----------+
| i-0bea52413bf5c2667  | InService   | Healthy  |
| i-0e477be2d66dfda58  | InService   | Healthy  |
+----------------------+-------------+----------+
```

### Result

**PASS**

Both application instances were:

- `InService`
- `Healthy`

This confirmed that the Auto Scaling Group successfully established the required application capacity.

---

# 4. EC2 Instance Validation

The application instances were deployed into private application subnets.

The final deployment used two healthy EC2 application instances across multiple Availability Zones.

### Result

**PASS**

The application compute tier was operational and running without public IP addresses.

---

# 5. AWS Systems Manager Validation

AWS Systems Manager Session Manager was used to access the application instances without requiring inbound SSH access.

A session was established using:

```powershell
aws ssm start-session `
  --target <INSTANCE-ID> `
  --region eu-west-1
```

The instance successfully accepted the Session Manager connection.

The following command confirmed successful cloud-init completion:

```bash
sudo cloud-init status --long
```

The result was:

```text
status: done
```

### Result

**PASS**

The EC2 instances were accessible through AWS Systems Manager.

---

# 6. EC2 Bootstrap Validation

The EC2 launch configuration bootstraps the application instances during initialization.

The bootstrap process was validated through:

```bash
sudo cat /var/log/fieldops-user-data.log
```

The bootstrap successfully:

1. Updated the operating system.
2. Installed Docker.
3. Verified required utilities.
4. Started Docker.
5. Enabled Docker as a system service.
6. Completed the FieldOps bootstrap process.

The bootstrap log concluded with:

```text
============================================================
FieldOps bootstrap test completed successfully
============================================================
```

### Result

**PASS**

The EC2 user-data/bootstrap process successfully prepared the application instances.

---

# 7. Docker Validation

Docker was installed and started successfully on the application instances.

Docker version was verified using:

```bash
docker --version
```

The deployed instance reported:

```text
Docker version 25.0.14
```

Docker service status was verified using:

```bash
sudo systemctl status docker --no-pager
```

The service reported:

```text
Active: active (running)
```

### Result

**PASS**

The Docker runtime was operational.

---

# 8. Amazon ECR Validation

The application container image was stored in Amazon ECR.

The validated repository was:

```text
fieldops-dev
```

The validated image tag was:

```text
v1.0.0
```

The image URI was:

```text
506813471880.dkr.ecr.eu-west-1.amazonaws.com/fieldops-dev:v1.0.0
```

The EC2 instance authenticated to ECR using:

```bash
aws ecr get-login-password --region eu-west-1 | \
sudo docker login --username AWS --password-stdin \
506813471880.dkr.ecr.eu-west-1.amazonaws.com
```

The authentication succeeded.

The image was then pulled using:

```bash
sudo docker pull \
506813471880.dkr.ecr.eu-west-1.amazonaws.com/fieldops-dev:v1.0.0
```

The image was successfully downloaded.

### Result

**PASS**

The EC2 application instances were able to authenticate to Amazon ECR and retrieve the application container image.

---

# 9. Application Container Validation

The application container was started using the deployed image and the database environment configuration.

The container was verified using:

```bash
sudo docker ps
```

The container reported:

```text
fieldops-api
```

with port mapping:

```text
0.0.0.0:8080->8080/tcp
```

Application logs were checked using:

```bash
sudo docker logs fieldops-api
```

The application reported:

```text
Started server process
Application startup complete.
Uvicorn running on http://0.0.0.0:8080
```

### Result

**PASS**

The FastAPI application successfully started inside the Docker container.

---

# 10. Application Health Validation

The application exposes a health endpoint:

```text
/health
```

The endpoint was tested locally on the EC2 instance using:

```bash
curl -i http://127.0.0.1:8080/health
```

The application returned:

```json
{
  "status": "healthy"
}
```

### Result

**PASS**

The application process was running and responding successfully.

---

# 11. ALB Target Group Validation

The Application Load Balancer target group was configured to perform health checks against:

```text
/health
```

on:

```text
Port: 8080
```

Target health was checked using:

```powershell
aws elbv2 describe-target-health `
  --target-group-arn "$(terraform output -raw application_target_group_arn)" `
  --region eu-west-1
```

The final state showed both targets as:

```text
State: healthy
```

The final validated targets were:

```text
i-0bea52413bf5c2667
i-0e477be2d66dfda58
```

### Result

**PASS**

Both EC2 application instances were successfully registered as healthy ALB targets.

---

# 12. Application Load Balancer Validation

The Application Load Balancer was verified using:

```powershell
aws elbv2 describe-load-balancers `
  --names fieldops-dev-alb `
  --region eu-west-1 `
  --query "LoadBalancers[0].[State.Code,DNSName]" `
  --output table
```

The ALB reported:

```text
State: active
```

The deployed ALB DNS name was:

```text
fieldops-dev-alb-1049523110.eu-west-1.elb.amazonaws.com
```

### Result

**PASS**

The Application Load Balancer was active and accepting traffic.

---

# 13. End-to-End Application Validation

The application was accessed through the public Application Load Balancer.

The root endpoint was tested using:

```powershell
curl.exe http://fieldops-dev-alb-1049523110.eu-west-1.elb.amazonaws.com/
```

The application returned:

```json
{
  "application": "FieldOps API",
  "version": "1.0.0",
  "environment": "development",
  "status": "running"
}
```

This confirmed successful traffic flow through:

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

### Result

**PASS**

The application was successfully accessed through the public ALB.

---

# 14. Database Connectivity Validation

The application provides a dedicated database health endpoint:

```text
/health/database
```

The endpoint performs a non-destructive database connectivity test using SQLAlchemy.

It was tested through the Application Load Balancer using:

```powershell
curl.exe http://fieldops-dev-alb-1049523110.eu-west-1.elb.amazonaws.com/health/database
```

The response was:

```json
{
  "status": "healthy",
  "database": "connected"
}
```

This confirmed the complete application-to-database path:

```text
Internet
   |
   v
Application Load Balancer
   |
   v
EC2 Application
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

### Result

**PASS**

The application successfully established connectivity to the private RDS PostgreSQL database.

---

# 15. Secrets Manager Validation

Database credentials were retrieved from AWS Secrets Manager during the application deployment process.

The secret was accessed from the EC2 instance using AWS IAM permissions associated with the application instance role.

The secret contained the database credentials required by the application.

The credentials were written to a protected runtime environment file:

```text
/run/fieldops/database.env
```

The file permissions were restricted using:

```bash
sudo chmod 600 /run/fieldops/database.env
```

Sensitive credential values were not exposed during validation.

### Result

**PASS**

The application successfully obtained database credentials without embedding them in the container image or Terraform configuration.

---

# 16. Database Health Endpoint Validation

The FastAPI application implements the database health check using a simple non-destructive query:

```sql
SELECT 1
```

The endpoint returned:

```json
{
  "status": "healthy",
  "database": "connected"
}
```

This confirms:

- DNS resolution to the RDS endpoint
- Network connectivity to PostgreSQL
- Security group connectivity
- Database authentication
- SQLAlchemy connectivity
- Application-to-database communication

### Result

**PASS**

---

# 17. Final Validation Summary

| Component | Validation | Result |
|---|---|---|
| VPC | Infrastructure deployed | PASS |
| Public subnets | Infrastructure deployed | PASS |
| Private application subnets | Infrastructure deployed | PASS |
| Private database subnets | Infrastructure deployed | PASS |
| Internet Gateway | Connectivity architecture validated | PASS |
| NAT Gateway | Private outbound connectivity | PASS |
| S3 VPC Endpoint | Private S3 connectivity configured | PASS |
| Application Load Balancer | ALB active | PASS |
| Target Group | Both targets healthy | PASS |
| Auto Scaling Group | Two instances InService / Healthy | PASS |
| EC2 | Application instances running | PASS |
| Systems Manager | Session established | PASS |
| Docker | Runtime active | PASS |
| Amazon ECR | Image authentication and pull successful | PASS |
| FastAPI | Application running | PASS |
| `/health` | Healthy response | PASS |
| RDS PostgreSQL | Database connectivity successful | PASS |
| Secrets Manager | Credentials retrieved successfully | PASS |
| `/health/database` | Database connected | PASS |
| End-to-end traffic | ALB to application to database | PASS |

---

# 18. Final Architecture Validation

The final validation demonstrated the following end-to-end architecture:

```text
                         INTERNET
                            |
                            v
                  Application Load Balancer
                            |
                     Target Group :8080
                            |
                 +----------+----------+
                 |                     |
                 v                     v
          EC2 Application 1     EC2 Application 2
                 |                     |
                 +----------+----------+
                            |
                         Docker
                            |
                         FastAPI
                            |
                       SQLAlchemy
                            |
                            v
                    RDS PostgreSQL
```

The application tier was successfully deployed across multiple Availability Zones and registered with the Application Load Balancer.

The final validation confirmed that the application remained reachable through the ALB and that the application could successfully communicate with the private PostgreSQL database.

---

# 19. Validation Conclusion

The core AWS multi-tier architecture was successfully deployed and validated end-to-end.

The validation demonstrates:

- Highly available application compute
- Private application networking
- Internet-facing load balancing
- Containerized application deployment
- Managed PostgreSQL database services
- Secure database credential management
- IAM-based AWS access
- Systems Manager-based administration
- ALB health monitoring
- Application health monitoring
- End-to-end database connectivity

The validated architecture provides the foundation for the next project phase, which focuses on production hardening, monitoring, observability, security, resilience, and operational automation.
