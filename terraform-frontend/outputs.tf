output "alb_dns_name" {
    description = "The DNS name for the ALB"
    value = aws_lb.order_alb.dns_name
}

output "ec2_instance_public_ip" {
    description = "EC2 instance public IP"
    value = aws_instance.web_server_order_processing.public_ip
}