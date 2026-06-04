terraform {
  backend "s3" {
    bucket = var.tf_state_bucket_name
    key    = "quizx/terraform.tfstate"
    region = var.aws_region

    encrypt = true
  }
}