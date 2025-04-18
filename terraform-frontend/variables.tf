variable "subnet_ids" {
  type = list(string)
  description = "List of subnet IDs to use"

}

variable "vpc_id" {
  description = "The VPC ID to use"
  type        = string
}

variable "key_name" {
  description = "The name of the EC2 Key Pair"
  type        = string
}

variable "ami_id" {
  description = "AMI ID to use for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "Instance type for the EC2 instance"
  type        = string
  default     = "t2.micro"
}

variable "my_public_ip" {
  description = "IP address of home network"
  type        = string
  default     = "0.0.0.0/0"
}
