terraform {
  backend "s3" {
    bucket = "quizx-terraform-state-379959319907"
    key    = "quizx/terraform.tfstate"
    region = "eu-west-2"

    encrypt = true
  }
}
