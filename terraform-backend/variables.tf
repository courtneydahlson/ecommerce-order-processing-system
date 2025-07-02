variable "notification_email" {
  description = "Email address for DLQ SNS notifications"
  type        = string
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}
