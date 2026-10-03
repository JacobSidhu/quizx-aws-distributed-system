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

resource "aws_iam_role_policy" "terraform_iam_bootstrap" {
  name = "${var.quizx_iam_role}-iam-bootstrap"
  role = aws_iam_role.quizx-terraform-automation-role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:ListPolicyVersions",
          "iam:ListEntitiesForPolicy",
          "iam:TagPolicy",
          "iam:UntagPolicy",
          "iam:GetRole",
          "iam:ListRoles",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:CreateServiceLinkedRole"
        ]
        Resource = "*"
      }
    ]
  })
}