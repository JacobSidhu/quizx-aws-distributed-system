terraform {
  backend "s3" {
    bucket = "quizx-terraform-state-2026"
    key    = "quizx/terraform.tfstate"
    region = "eu-west-2"

    encrypt = true
  }
}