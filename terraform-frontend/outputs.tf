output "alb_dns_name" {
    description = "The DNS name for the ALB"
    value = aws_lb.order_alb.dns_name
}
