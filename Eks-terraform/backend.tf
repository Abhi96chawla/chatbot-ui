terraform {
  backend "s3" {
    bucket = "terraform-state-bucketabhi-6222" # Replace with your actual S3 bucket name
    key    = "EKS/terraform.tfstate"
    region = "ap-south-1"
  }
}
