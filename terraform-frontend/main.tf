# EC2 instance

resource "aws_instance" "web_server_order_processing" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  associate_public_ip_address = true
  key_name               = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              yum install -y git
              cd /var/www/html
              git clone -b dev https://github.com/courtneydahlson/ecommerce-order-processing-system.git
              cp -r ecommerce-order-processing-system/frontend/* .
              EOF

  tags = {
    Name = "WebServer"
  }
}


# Security Group EC2 instance
resource "aws_security_group" "instance_sg" {
  name        = "order-web-instance-sg-tf"
  description = "Allow SSH"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_public_ip] 
  }

  ingress {
    description = "Allow HTTP traffic from ALB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

    ingress {
    description = "Allow HTTPS traffic from ALB"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Security Group Application Load balancer
resource "aws_security_group" "alb_sg" {
  name        = "order-web-alb-sg-tf"
  description = "Allow HTTP HTTPS"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Public HTTP
  }

  ingress {
    from_port   = 443
    to_port     = 443
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

# Target Group
resource "aws_lb_target_group" "order_tf" {
  name     = "order-tf"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

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

# ALB
resource "aws_lb" "order_alb" {
  name               = "order-alb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.subnet_ids
}

# Listener that listens for connections on port 80 and forwards the request to a target group
resource "aws_lb_listener" "order_listener" {
  load_balancer_arn = aws_lb.order_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.order_tf.arn
  }
}

# Attach EC2 to Target Group
resource "aws_lb_target_group_attachment" "order_attach" {
  target_group_arn = aws_lb_target_group.order_tf.arn
  target_id        = aws_instance.web_server_order_processing.id
  port             = 80
}