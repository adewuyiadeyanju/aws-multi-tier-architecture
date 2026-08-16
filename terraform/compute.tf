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

    dnf update -y
    dnf install -y python3 python3-pip

    mkdir -p /opt/fieldops

    cat > /opt/fieldops/app.py <<'PYTHON'
    from http.server import BaseHTTPRequestHandler, HTTPServer

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/health":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b'{"status":"healthy"}')
            else:
                self.send_response(200)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                self.wfile.write(b"FieldOps application is running")

        def log_message(self, format, *args):
            return

    server = HTTPServer(("0.0.0.0", 8080), Handler)
    server.serve_forever()
    PYTHON

    cat > /etc/systemd/system/fieldops.service <<'SERVICE'
    [Unit]
    Description=FieldOps Application
    After=network.target

    [Service]
    ExecStart=/usr/bin/python3 /opt/fieldops/app.py
    Restart=always
    User=root

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable fieldops
    systemctl start fieldops
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