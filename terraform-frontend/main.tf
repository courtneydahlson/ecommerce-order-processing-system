

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

#Target Group
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


#Launch Template

resource "aws_launch_template" "web_server_lt" {
  name_prefix   = "order-processing-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.instance_sg.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd git
              systemctl start httpd
              systemctl enable httpd
              cd /var/www/html
              #git clone -b dev https://github.com/courtneydahlson/ecommerce-order-processing-system.git
              #cp -r ecommerce-order-processing-system/frontend/* .
              #rm -rf ecommerce-order-processing-system
              #aws s3 cp s3://order-processing-system-config/frontend 
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "WebServer"
    }
  }
}

resource "aws_iam_role" "ec2_s3_access" {
  name = "ec2-s3-access-role-tf"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "s3_access_policy" {
  name = "ec2-s3-access-policy-tf"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_frontend}",
          "arn:aws:s3:::${var.s3_bucket_frontend}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.ec2_s3_access.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-s3-instance-profile-tf"
  role = aws_iam_role.ec2_s3_access.name
}


# Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  name                      = "order-processing-asg-tf"
  max_size                  = var.asg_max_size
  min_size                  = var.asg_min_size
  desired_capacity          = var.asg_desired_capacity
  vpc_zone_identifier       = var.subnet_ids
  target_group_arns         = [aws_lb_target_group.order_tf.arn]
  health_check_type         = "EC2"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.web_server_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "WebServer"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}