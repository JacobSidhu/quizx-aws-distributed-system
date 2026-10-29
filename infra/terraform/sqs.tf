# ==============================================================================
# SQS queues
# ==============================================================================
# Message queues between the QuizX services:
#
#   submit_app  messages published by the submit app
#   moderate    messages for the moderator service
#
# Names follow "<project>-<environment>-*", which the bootstrap execution
# policy uses to scope SQS permissions.
# ==============================================================================
resource "aws_sqs_queue" "queue" {
  for_each = {
    submit_app = "${local.name_prefix}-submit-app-queue"
    moderate   = "${local.name_prefix}-moderate-queue"
  }

  name = each.value
  tags = local.common_tags
}
