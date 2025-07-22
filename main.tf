provider "aws" {
  region = "ap-south-1"
}

# Fetch default VPC
data "aws_vpc" "default" {
  default = true
}

# Fetch default subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Use first default subnet
data "aws_subnet" "default_subnet" {
  id = data.aws_subnets.default.ids[0]
}

# Create a Security Group for ALB and EC2s
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

# EC2 Instance 1
resource "aws_instance" "web1" {
  ami                    = "ami-0b32d400456908bf9"
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnet.default_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from Web Server 1</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "web-server-1"
  }
}

# EC2 Instance 2
resource "aws_instance" "web2" {
  ami                    = "ami-0b32d400456908bf9"
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnet.default_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from Web Server 2</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "web-server-2"
  }
}

# Application Load Balancer
resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Name = "web-alb"
  }
}

# Target Group for ALB
resource "aws_lb_target_group" "web_tg" {
  name        = "web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"
}

# Attach EC2 Instances to Target Group
resource "aws_lb_target_group_attachment" "attach_web1" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach_web2" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web2.id
  port             = 80
}

# ALB Listener
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}
