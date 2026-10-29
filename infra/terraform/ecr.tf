# ==============================================================================
# ECR
# ==============================================================================
# Container image repository for the QuizX services. Tags are immutable, so a
# pushed tag always refers to the same image, and every push is scanned for
# vulnerabilities.
# ==============================================================================
resource "aws_ecr_repository" "ecr" {
  name                 = "${local.name_prefix}-ecr-repository"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}
