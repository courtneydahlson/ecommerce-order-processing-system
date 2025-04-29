vpc_id    = "vpc-03d8d930af0429cba"
subnet_ids = [
    "subnet-04ce8d652cd0911e1",
    "subnet-057c9e37d1bc939c1"
]
key_name = "EC2 Tutorial"
ami_id        = "ami-00a929b66ed6e0de6"
instance_type = "t2.micro"
my_public_ip = "0.0.0.0/0"
asg_min_size         = 1
asg_max_size         = 3
asg_desired_capacity = 2
s3_bucket_frontend = "order-processing-system-config"