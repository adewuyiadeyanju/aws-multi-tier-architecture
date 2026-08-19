data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_launch_template" "application" {
  name = "fieldops-${var.environment}-app"

  image_id = data.aws_ssm_parameter.amazon_linux_2023.value

  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.application.name
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  vpc_security_group_ids = [
    aws_security_group.application.id
  ]

  user_data = base64encode(<<-EOF
#!/bin/bash

set -euo pipefail

# ------------------------------------------------------------
# FieldOps EC2 bootstrap
# ------------------------------------------------------------

exec > >(tee /var/log/fieldops-user-data.log | logger -t fieldops-user-data -s 2>/dev/console) 2>&1

echo "============================================================"
echo "FieldOps bootstrap started"
echo "============================================================"

# ------------------------------------------------------------
# AWS region
# ------------------------------------------------------------

export AWS_DEFAULT_REGION="${var.aws_region}"
export AWS_REGION="${var.aws_region}"

echo "AWS Region: $${AWS_DEFAULT_REGION}"

# ------------------------------------------------------------
# Update operating system
# ------------------------------------------------------------

echo "Updating operating system..."

dnf update -y

# ------------------------------------------------------------
# Install required dependencies
#
# curl is already available in the Amazon Linux 2023 AMI.
# We verify it rather than installing it.
# ------------------------------------------------------------

echo "Installing Docker and jq..."

dnf install -y docker jq

# ------------------------------------------------------------
# Verify AWS CLI
# ------------------------------------------------------------

echo "Checking AWS CLI..."

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: AWS CLI is not available."
  exit 1
fi

aws --version

# ------------------------------------------------------------
# Verify Docker
# ------------------------------------------------------------

echo "Checking Docker..."

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker is not available."
  exit 1
fi

docker --version

# ------------------------------------------------------------
# Verify jq
# ------------------------------------------------------------

echo "Checking jq..."

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is not available."
  exit 1
fi

jq --version

# ------------------------------------------------------------
# Verify curl
# ------------------------------------------------------------

echo "Checking curl..."

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl is not available."
  exit 1
fi

curl --version | head -n 1

# ------------------------------------------------------------
# Start Docker
# ------------------------------------------------------------

echo "Starting Docker..."

systemctl enable docker
systemctl start docker

if ! systemctl is-active --quiet docker; then
  echo "ERROR: Docker service failed to start."
  systemctl status docker --no-pager || true
  exit 1
fi

echo "Docker is running successfully."

# ------------------------------------------------------------
# Verify EC2 IAM role
# ------------------------------------------------------------

echo "Verifying EC2 IAM credentials..."

aws sts get-caller-identity

echo "EC2 IAM credentials verified."

# ------------------------------------------------------------
# ECR configuration
# ------------------------------------------------------------

ECR_REPOSITORY="${aws_ecr_repository.fieldops.repository_url}"
ECR_REGISTRY="$${ECR_REPOSITORY%%/*}"
ECR_IMAGE="$${ECR_REPOSITORY}:${var.application_image_tag}"

echo "ECR repository: $${ECR_REPOSITORY}"
echo "ECR registry:   $${ECR_REGISTRY}"
echo "ECR image:      $${ECR_IMAGE}"

# ------------------------------------------------------------
# Authenticate to ECR
# ------------------------------------------------------------

echo "Logging into Amazon ECR..."

aws ecr get-login-password \
  --region "$${AWS_DEFAULT_REGION}" | \
  docker login \
    --username AWS \
    --password-stdin "$${ECR_REGISTRY}"

echo "ECR login successful."

# ------------------------------------------------------------
# Pull application image
# ------------------------------------------------------------

echo "Pulling FieldOps image..."

docker pull "$${ECR_IMAGE}"

echo "FieldOps image pulled successfully."

# ------------------------------------------------------------
# Retrieve database credentials from Secrets Manager
#
# The RDS-managed secret contains:
#   username
#   password
#
# Host, port and database name come from the RDS resource.
# ------------------------------------------------------------

echo "Retrieving database credentials from Secrets Manager..."

SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "${aws_db_instance.fieldops.master_user_secret[0].secret_arn}" \
  --region "$${AWS_DEFAULT_REGION}" \
  --query "SecretString" \
  --output text)

if [ -z "$${SECRET_JSON}" ] || [ "$${SECRET_JSON}" = "None" ]; then
  echo "ERROR: Database secret was empty."
  exit 1
fi

echo "Database secret retrieved successfully."

# ------------------------------------------------------------
# Extract username and password from Secrets Manager
# ------------------------------------------------------------

DATABASE_USERNAME=$(echo "$${SECRET_JSON}" | jq -r '.username')
DATABASE_PASSWORD=$(echo "$${SECRET_JSON}" | jq -r '.password')

# ------------------------------------------------------------
# Get database connection information from RDS
# ------------------------------------------------------------

DATABASE_HOST="${aws_db_instance.fieldops.address}"
DATABASE_PORT="${aws_db_instance.fieldops.port}"
DATABASE_NAME="${aws_db_instance.fieldops.db_name}"

echo "Database host: $${DATABASE_HOST}"
echo "Database port: $${DATABASE_PORT}"
echo "Database name: $${DATABASE_NAME}"
echo "Database username: $${DATABASE_USERNAME}"

# ------------------------------------------------------------
# Validate database configuration
# ------------------------------------------------------------

if [ -z "$${DATABASE_HOST}" ] || [ "$${DATABASE_HOST}" = "null" ]; then
  echo "ERROR: DATABASE_HOST is missing."
  exit 1
fi

if [ -z "$${DATABASE_PORT}" ] || [ "$${DATABASE_PORT}" = "null" ]; then
  echo "ERROR: DATABASE_PORT is missing."
  exit 1
fi

if [ -z "$${DATABASE_NAME}" ] || [ "$${DATABASE_NAME}" = "null" ]; then
  echo "ERROR: DATABASE_NAME is missing."
  exit 1
fi

if [ -z "$${DATABASE_USERNAME}" ] || [ "$${DATABASE_USERNAME}" = "null" ]; then
  echo "ERROR: DATABASE_USERNAME is missing."
  exit 1
fi

if [ -z "$${DATABASE_PASSWORD}" ] || [ "$${DATABASE_PASSWORD}" = "null" ]; then
  echo "ERROR: DATABASE_PASSWORD is missing."
  exit 1
fi

echo "Database configuration validated successfully."

# ------------------------------------------------------------
# Create temporary database environment file
# ------------------------------------------------------------

mkdir -p /run/fieldops

cat > /run/fieldops/database.env <<ENV
DATABASE_HOST=$${DATABASE_HOST}
DATABASE_PORT=$${DATABASE_PORT}
DATABASE_NAME=$${DATABASE_NAME}
DATABASE_USERNAME=$${DATABASE_USERNAME}
DATABASE_PASSWORD=$${DATABASE_PASSWORD}
ENV

chmod 600 /run/fieldops/database.env

echo "Temporary database environment file created."

# ------------------------------------------------------------
# Remove previous container if present
# ------------------------------------------------------------

echo "Removing existing FieldOps container if present..."

docker rm -f fieldops-api 2>/dev/null || true

# ------------------------------------------------------------
# Start FieldOps API
# ------------------------------------------------------------

echo "Starting FieldOps API..."

docker run -d \
  --name fieldops-api \
  --restart unless-stopped \
  --env-file /run/fieldops/database.env \
  -p 8080:8080 \
  "$${ECR_IMAGE}"

echo "FieldOps container created."

# ------------------------------------------------------------
# Verify container is running
# ------------------------------------------------------------

echo "Waiting for FieldOps container..."

sleep 5

if ! docker ps \
  --filter "name=fieldops-api" \
  --filter "status=running" | \
  grep -q fieldops-api; then

  echo "ERROR: FieldOps container is not running."

  echo "Container status:"
  docker ps -a

  echo "Container logs:"
  docker logs fieldops-api 2>&1 || true

  exit 1
fi

echo "FieldOps container is running."

# ------------------------------------------------------------
# Verify local application health
# ------------------------------------------------------------

echo "Checking local FieldOps health endpoint..."

HEALTH_CHECK_PASSED=false

for i in {1..12}; do

  if curl -fsS http://127.0.0.1:8080/health; then
    echo ""
    echo "FieldOps local health check successful."
    HEALTH_CHECK_PASSED=true
    break
  fi

  echo "Health check attempt $${i}/12 failed. Waiting..."

  sleep 5

done

if [ "$${HEALTH_CHECK_PASSED}" != "true" ]; then

  echo "ERROR: FieldOps application failed local health check."

  echo "Container status:"
  docker ps -a

  echo "Container logs:"
  docker logs fieldops-api 2>&1 || true

  exit 1
fi

# ------------------------------------------------------------
# Remove temporary credentials
# ------------------------------------------------------------

rm -f /run/fieldops/database.env

echo "Temporary database environment file removed."

# ------------------------------------------------------------
# Bootstrap complete
# ------------------------------------------------------------

echo "============================================================"
echo "FieldOps bootstrap completed successfully"
echo "============================================================"

EOF
)

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "fieldops-${var.environment}-app"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "application" {
  name = "fieldops-${var.environment}-asg"

  min_size         = 2
  desired_capacity = 2
  max_size         = 4

  vpc_zone_identifier = aws_subnet.application[*].id

  target_group_arns = [
    aws_lb_target_group.application.arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.application.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "fieldops-${var.environment}-app"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}