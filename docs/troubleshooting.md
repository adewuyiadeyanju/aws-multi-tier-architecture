# Troubleshooting

## 1. Overview

This document records the main troubleshooting scenarios encountered while
deploying and validating the AWS multi-tier FieldOps application.

The purpose is to provide practical operational guidance for diagnosing issues
across:

- EC2
- Docker
- Amazon ECR
- AWS Secrets Manager
- FastAPI
- RDS PostgreSQL
- Application Load Balancer
- Auto Scaling
- AWS Systems Manager
- Terraform
- AWS CLI

The troubleshooting procedures are based on issues encountered during the
actual deployment and validation of the project.

---

## 2. Troubleshooting Approach

Troubleshooting was performed from the lowest infrastructure layer toward the
application layer.

The general approach was:

```text
1. Verify AWS infrastructure
          |
          v
2. Verify EC2 instance state
          |
          v
3. Verify Systems Manager access
          |
          v
4. Verify Docker
          |
          v
5. Verify ECR authentication
          |
          v
6. Verify container startup
          |
          v
7. Verify application health
          |
          v
8. Verify ALB target health
          |
          v
9. Verify database connectivity
```

This approach helps isolate whether a failure originates from infrastructure,
networking, authentication, container runtime, application startup, or the
database layer.

---

# 3. Docker Permission Denied

## Symptom

Running Docker as the `ssm-user` resulted in:

```text
permission denied while trying to connect to the Docker daemon socket at
unix:///var/run/docker.sock
```

For example:

```bash
docker pull 506813471880.dkr.ecr.eu-west-1.amazonaws.com/fieldops-dev:v1.0.0
```

returned:

```text
permission denied while trying to connect to the Docker daemon socket
```

## Cause

The Docker daemon socket:

```text
/var/run/docker.sock
```

was not accessible to the current user.

The Docker command therefore could not communicate with the Docker daemon.

## Resolution

Run Docker commands with `sudo`:

```bash
sudo docker pull <ECR-IMAGE-URI>
```

For example:

```bash
sudo docker pull \
506813471880.dkr.ecr.eu-west-1.amazonaws.com/fieldops-dev:v1.0.0
```

## Validation

Docker successfully pulled the image after using `sudo`.

### Result

**RESOLVED**

---

# 4. ECR Authentication Context Mismatch

## Symptom

ECR authentication succeeded when running:

```bash
aws ecr get-login-password --region eu-west-1 | \
docker login --username AWS --password-stdin \
506813471880.dkr.ecr.eu-west-1.amazonaws.com
```

However, running:

```bash
sudo docker pull \
506813471880.dkr.ecr.eu-west-1.amazonaws.com/fieldops-dev:v1.0.0
```

returned:

```text
no basic auth credentials
```

## Cause

Docker credentials were stored in the current user's Docker configuration:

```text
/home/ssm-user/.docker/config.json
```

When `sudo docker` was executed, Docker operated under the `root` user.

The root user's Docker configuration was different:

```text
/root/.docker/config.json
```

Therefore, the credentials available to `ssm-user` were not automatically
available to Docker running as `root`.

## Resolution

Authenticate to ECR using the same user context that executes Docker:

```bash
aws ecr get-login-password --region eu-west-1 | \
sudo docker login --username AWS --password-stdin \
506813471880.dkr.ecr.eu-west-1.amazonaws.com
```

The command returned:

```text
Login Succeeded
```

The image could then be pulled successfully:

```bash
sudo docker pull \
506813471880.dkr.ecr.eu-west-1.amazonaws.com/fieldops-dev:v1.0.0
```

## Key Lesson

When `sudo docker` is used, Docker authentication must be available to the
`root` user.

Authentication context and Docker execution context must therefore match.

### Result

**RESOLVED**

---

# 5. Docker Credential Warning

## Symptom

Docker displayed:

```text
WARNING! Your password will be stored unencrypted in
/home/ssm-user/.docker/config.json.
```

or:

```text
WARNING! Your password will be stored unencrypted in
/root/.docker/config.json.
```

## Cause

Docker was storing the registry credential directly in its Docker
configuration rather than using a credential helper.

## Impact

This warning does not prevent authentication or image pulls.

It indicates that credentials are stored locally in Docker configuration.

## Resolution

For the portfolio deployment, the immediate requirement was to authenticate
the EC2 instance to ECR and pull the container image.

For a production implementation, a Docker credential helper or another
appropriate credential-management mechanism should be evaluated.

The warning should not be confused with an ECR authentication failure.

### Result

**Acknowledged**

---

# 6. Secrets Manager Fields Returned as Null

## Symptom

The initial attempt to construct the database environment file used:

```bash
jq -r '"DATABASE_HOST=\(.host)\nDATABASE_PORT=\(.port)\nDATABASE_NAME=\(.dbname)\nDATABASE_USERNAME=\(.username)\nDATABASE_PASSWORD=\(.password)"'
```

The resulting file contained:

```text
DATABASE_HOST=null
DATABASE_PORT=null
DATABASE_NAME=null
DATABASE_USERNAME=fieldopsadmin
```

## Investigation

The secret was inspected using:

```bash
sudo jq 'keys' /tmp/db-secret.json
```

The result was:

```json
[
  "password",
  "username"
]
```

This demonstrated that the Secrets Manager secret contained only:

```text
username
password
```

It did not contain:

```text
host
port
dbname
```

## Cause

The RDS connection information was not stored as part of the secret.

The database endpoint and database configuration therefore had to be supplied
separately.

## Resolution

The username and password were extracted from the secret:

```bash
sudo jq -r '"DATABASE_USERNAME=\(.username)\nDATABASE_PASSWORD=\(.password)"' \
/tmp/db-secret.json | \
sudo tee /run/fieldops/credentials.env >/dev/null
```

The database configuration was then combined with the credentials:

```bash
sudo tee /run/fieldops/database.env >/dev/null <<EOF
DATABASE_HOST=fieldops-dev-postgres.cvuy4w8e0oic.eu-west-1.rds.amazonaws.com
DATABASE_PORT=5432
DATABASE_NAME=fieldops
$(sudo cat /run/fieldops/credentials.env)
EOF
```

The resulting configuration contained:

```text
DATABASE_HOST=fieldops-dev-postgres.cvuy4w8e0oic.eu-west-1.rds.amazonaws.com
DATABASE_PORT=5432
DATABASE_NAME=fieldops
DATABASE_USERNAME=fieldopsadmin
DATABASE_PASSWORD=<secret>
```

The password was not displayed during validation.

## File Protection

The environment file was protected using:

```bash
sudo chmod 600 /run/fieldops/database.env
```

## Key Lesson

Secrets Manager should contain only the values appropriate for the selected
secret design.

Database endpoint metadata and credentials may be managed separately, but the
application configuration must ultimately receive the complete connection
information required by the application.

### Result

**RESOLVED**

---

# 7. Container Startup Validation

## Symptom

After starting the container, it was necessary to determine whether the
application itself had successfully started.

## Diagnostic Commands

Check the container:

```bash
sudo docker ps
```

Check application logs:

```bash
sudo docker logs fieldops-api
```

The successful application startup reported:

```text
Started server process [1]
Waiting for application startup.
Application startup complete.
Uvicorn running on http://0.0.0.0:8080
```

## Resolution

No application startup error was present.

The container was running and listening on port `8080`.

### Result

**PASS**

---

# 8. Application Health Check Failure

## Symptom

If the ALB reports an unhealthy target, the first application-level check
should be performed directly against the instance.

## Diagnostic Command

From the EC2 instance:

```bash
curl -i http://127.0.0.1:8080/health
```

The expected response is:

```json
{
  "status": "healthy"
}
```

## Interpretation

### If `/health` succeeds

The application is running locally.

The investigation should then move toward:

- Security groups
- Target group configuration
- Health check path
- Health check port
- ALB connectivity
- Network ACLs

### If `/health` fails

Investigate:

- Docker container status
- Docker logs
- Application startup
- Port mapping
- Environment variables
- Application configuration

### Result

The final deployment returned:

```text
HTTP/1.1 200 OK
```

with:

```json
{
  "status": "healthy"
}
```

**PASS**

---

# 9. ALB Target Initially Unhealthy

## Symptom

During the deployment process, an ALB target was observed in the:

```text
unhealthy
```

state.

The target health output included:

```text
State: unhealthy
Reason: Target.FailedHealthChecks
```

## Troubleshooting Approach

The investigation was performed in layers.

### Step 1 — Verify the EC2 instance

Confirm the instance is:

```text
InService
Healthy
```

using:

```powershell
aws autoscaling describe-auto-scaling-groups `
  --auto-scaling-group-names fieldops-dev-asg `
  --region eu-west-1 `
  --query "AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]" `
  --output table
```

### Step 2 — Verify Docker

```bash
sudo docker ps
```

### Step 3 — Verify application logs

```bash
sudo docker logs fieldops-api --tail 50
```

### Step 4 — Test the application locally

```bash
curl -i http://127.0.0.1:8080/health
```

### Step 5 — Verify target group configuration

Check:

```text
Target port: 8080
Health check path: /health
```

### Step 6 — Check security groups

The application security group must permit TCP `8080` from the ALB security
group.

## Final State

After correcting the deployment configuration and restarting the affected
application instance, both ALB targets became healthy.

Final target states:

```text
i-0bea52413bf5c2667  -> healthy
i-0e477be2d66dfda58  -> healthy
```

### Result

**RESOLVED**

---

# 10. Terraform Not Found on EC2

## Symptom

The following command was attempted from an EC2 Systems Manager shell:

```bash
terraform output -raw application_target_group_arn
```

The shell returned:

```text
terraform: command not found
```

## Cause

Terraform was installed and used on the development workstation, not on the
EC2 application instance.

The EC2 host was not intended to act as the Terraform execution environment.

## Resolution

Run Terraform commands from the workstation containing the Terraform project.

For example, from the Terraform directory:

```powershell
terraform output -raw application_target_group_arn
```

Then use the resulting ARN with:

```powershell
aws elbv2 describe-target-health `
  --target-group-arn "<TARGET-GROUP-ARN>" `
  --region eu-west-1
```

## Key Lesson

Separate:

```text
Terraform workstation
```

from:

```text
EC2 application runtime
```

Terraform is responsible for infrastructure provisioning and querying
Terraform-managed outputs. EC2 is responsible for running the application.

### Result

**RESOLVED**

---

# 11. Shell Syntax Differences

## Symptom

Commands written for PowerShell were initially attempted in the Linux shell
on the EC2 instance.

For example:

```text
`
```

was used as a line continuation character.

This caused command parsing problems.

## Cause

PowerShell and Linux shells use different command syntax.

### PowerShell

PowerShell uses the backtick:

```powershell
`
```

for line continuation.

### Linux shell

Linux shells use:

```bash
\
```

for line continuation.

## Correct Linux Example

```bash
aws ecr get-login-password --region eu-west-1 | \
sudo docker login --username AWS --password-stdin \
506813471880.dkr.ecr.eu-west-1.amazonaws.com
```

## Correct PowerShell Example

```powershell
aws elbv2 describe-load-balancers `
  --names fieldops-dev-alb `
  --region eu-west-1
```

## Key Lesson

Always identify the execution environment before copying a command:

```text
Windows PowerShell
        vs
Linux shell / SSM session
```

### Result

**RESOLVED**

---

# 12. AWS CLI Target Health Validation

## Recommended Command

From the Terraform workstation:

```powershell
aws elbv2 describe-target-health `
  --target-group-arn "$(terraform output -raw application_target_group_arn)" `
  --region eu-west-1
```

The expected result is that each registered target reports:

```text
"State": "healthy"
```

The final deployment returned both targets as healthy.

### Result

**PASS**

---

# 13. Application Logs

Application logs are one of the first places to inspect when a target becomes
unhealthy or an application endpoint stops responding.

Use:

```bash
sudo docker logs fieldops-api --tail 50
```

For continuous logs:

```bash
sudo docker logs -f fieldops-api
```

To inspect container state:

```bash
sudo docker ps
```

To inspect the container configuration:

```bash
sudo docker inspect fieldops-api
```

Useful information includes:

- Container state
- Port mappings
- Environment configuration
- Restart status
- Network configuration

---

# 14. Database Connectivity Troubleshooting

## Symptom

The application may be running successfully while database connectivity
fails.

The application provides:

```text
/health/database
```

Use:

```powershell
curl.exe http://<ALB-DNS-NAME>/health/database
```

Expected response:

```json
{
  "status": "healthy",
  "database": "connected"
}
```

## If the Database Check Fails

Investigate in this order:

### 1. Verify database configuration

Check:

```text
DATABASE_HOST
DATABASE_PORT
DATABASE_NAME
DATABASE_USERNAME
DATABASE_PASSWORD
```

### 2. Verify RDS status

Confirm that the RDS instance is available.

### 3. Verify security groups

The database security group should allow PostgreSQL traffic:

```text
TCP 5432
```

from the application security group.

### 4. Verify private networking

The application must be able to reach the RDS private endpoint through the
VPC network.

### 5. Verify credentials

Confirm that the credentials retrieved from Secrets Manager correspond to the
database.

### 6. Verify application logs

```bash
sudo docker logs fieldops-api --tail 50
```

---

# 15. Secrets and Environment File Troubleshooting

The runtime database configuration is stored in:

```text
/run/fieldops/database.env
```

To inspect non-sensitive variables:

```bash
sudo grep -E \
'DATABASE_HOST|DATABASE_PORT|DATABASE_NAME|DATABASE_USERNAME' \
/run/fieldops/database.env
```

Expected output:

```text
DATABASE_HOST=<RDS-ENDPOINT>
DATABASE_PORT=5432
DATABASE_NAME=fieldops
DATABASE_USERNAME=fieldopsadmin
```

Do not print the password during troubleshooting.

Verify permissions:

```bash
sudo ls -l /run/fieldops/database.env
```

The file should be restricted to root access.

---

# 16. Container Restart Troubleshooting

If the application container stops:

```bash
sudo docker ps -a
```

Inspect the container:

```bash
sudo docker inspect fieldops-api
```

Review logs:

```bash
sudo docker logs fieldops-api --tail 100
```

Restart the container if appropriate:

```bash
sudo docker restart fieldops-api
```

Then validate:

```bash
sudo docker ps
```

and:

```bash
curl -i http://127.0.0.1:8080/health
```

---

# 17. ECR Image Troubleshooting

If the image cannot be pulled, first authenticate:

```bash
aws ecr get-login-password --region eu-west-1 | \
sudo docker login --username AWS --password-stdin \
506813471880.dkr.ecr.eu-west-1.amazonaws.com
```

Then retry:

```bash
sudo docker pull \
506813471880.dkr.ecr.eu-west-1.amazonaws.com/fieldops-dev:v1.0.0
```

If authentication fails, verify:

- AWS CLI credentials
- IAM permissions
- AWS region
- ECR repository name
- Image tag
- Docker execution user

The image URI must match the deployed repository and tag exactly.

---

# 18. ALB Troubleshooting Checklist

When an ALB target is unhealthy, check the following:

```text
[ ] EC2 instance is running
[ ] Auto Scaling Group reports Healthy
[ ] Systems Manager session works
[ ] Docker service is running
[ ] Container is running
[ ] Container is listening on port 8080
[ ] /health returns HTTP 200 locally
[ ] Target group port is 8080
[ ] Target group health check path is /health
[ ] ALB security group permits HTTP traffic
[ ] Application security group permits TCP 8080 from ALB SG
[ ] Network routing is correct
[ ] Target is registered with the target group
```

This checklist provides a repeatable diagnostic process.

---

# 19. Infrastructure Validation Checklist

Before declaring the deployment successful, validate:

```text
[ ] Terraform apply completed successfully
[ ] VPC created
[ ] Subnets created
[ ] Route tables configured
[ ] Internet Gateway configured
[ ] NAT Gateway available
[ ] Security groups configured
[ ] IAM roles created
[ ] RDS available
[ ] ALB active
[ ] Target group created
[ ] Auto Scaling Group healthy
[ ] EC2 instances InService
[ ] Systems Manager available
[ ] Docker running
[ ] ECR authentication successful
[ ] Application container running
[ ] /health returns healthy
[ ] ALB targets healthy
[ ] /health/database returns connected
```

---

# 20. Cost-Controlled Teardown

This portfolio environment is not intended to remain continuously deployed.

AWS resources such as:

- NAT Gateway
- Application Load Balancer
- EC2 instances
- RDS PostgreSQL

can generate ongoing costs.

After completing demonstrations and validation, the infrastructure can be
destroyed using Terraform.

From the Terraform directory:

```powershell
terraform destroy
```

Review the proposed resources carefully before confirming destruction.

The Amazon ECR repository/image may be retained separately so that the
container artifact does not need to be rebuilt solely to demonstrate the
project again.

## Important

Terraform should remain the source of truth for resources managed by the
project.

Do not manually delete Terraform-managed resources unless there is a specific
recovery requirement.

---

# 21. Troubleshooting Principles

The deployment reinforced several practical cloud troubleshooting
principles:

### Start with the lowest failing layer

Do not immediately troubleshoot the ALB when the application itself is not
running.

### Validate locally before validating externally

For example:

```text
curl 127.0.0.1:8080/health
```

should succeed before investigating ALB behavior.

### Match credentials to execution context

A Docker login performed by one Linux user does not necessarily authenticate
Docker when executed through `sudo`.

### Separate infrastructure tools from application runtime

Terraform belongs on the infrastructure management workstation.

The EC2 instance should primarily run and expose the application.

### Treat secrets carefully

Never expose database passwords in logs, terminal output, documentation, or
source control.

### Use evidence rather than assumptions

Use:

```bash
docker ps
docker logs
curl
aws elbv2 describe-target-health
aws autoscaling describe-auto-scaling-groups
```

to establish the actual state of the system.

---

# 22. Troubleshooting Conclusion

The deployment encountered several practical issues involving Docker
permissions, ECR authentication context, database secret structure, shell
syntax, Terraform execution location, and ALB target health.

These issues were resolved through a structured diagnostic process.

The final system achieved:

```text
EC2
  |
  +--> Docker
  |
  +--> ECR authentication
  |
  +--> FastAPI container
  |
  +--> ALB health = healthy
  |
  +--> RDS connectivity = healthy
```

The troubleshooting experience demonstrates operational understanding beyond
Terraform provisioning and provides a practical reference for future
deployments of the architecture.
