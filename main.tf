provider "aws" {
  region = "ap-south-1"
}

# Get default VPC and subnet
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_subnet" "default_subnet" {
  id = data.aws_subnet_ids.default.ids[0]
}

# Security Group allowing HTTP and SSH
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# User data to install HTTPD
locals {
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "Hello from $(hostname)" > /var/www/html/index.html
            EOF
}

# EC2 Instance 1
resource "aws_instance" "web1" {
  ami                    = "ami-0b32d400456908bf9"  # Amazon Linux 2023 in ap-south-1
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnet.default_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data              = local.user_data
  tags = {
    Name = "WebServer1"
  }
}

# EC2 Instance 2
resource "aws_instance" "web2" {
  ami                    = "ami-0b32d400456908bf9"
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnet.default_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data              = local.user_data
  tags = {
    Name = "WebServer2"
  }
}

# Load Balancer
resource "aws_lb" "app_lb" {
  name               = "web-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = data.aws_subnet_ids.default.ids
}

# Target Group
resource "aws_lb_target_group" "web_tg" {
  name     = "web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Register instances to target group
resource "aws_lb_target_group_attachment" "web1_attach" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web2_attach" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web2.id
  port             = 80
}

# Listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# Output Load Balancer DNS
output "load_balancer_dns" {
  value = aws_lb.app_lb.dns_name
}
