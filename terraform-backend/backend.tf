terraform {
  backend "s3" {
    bucket = "terraform-s3-bucket-order-processing-system"
    key    = "terraform/backend/terraform.tfstate"
    region = "us-east-1"                    
    encrypt = true 
    use_lockfile = true                         
  }
}
