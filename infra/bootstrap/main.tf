terraform {
    backend "s3" { encrypt = true }
}

// Creating IAM Role for Terraform automation with necessary policies attached for SQS, API Gateway, S3, and ACM access.
resource "aws_iam_role" "quizx-terraform-automation-role" {
  name = var.quizx_iam_role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:user/${var.quizx_iam_user}"
        }
      }
    ]
  })
}