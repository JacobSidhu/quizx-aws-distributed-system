// Publishes new questions to the submitted-questions SQS queue. The client and
// queue URL are created on first use so the server can start before AWS is
// reachable; the readiness probe reports when the queue is available.
const {
  GetQueueAttributesCommand,
  SendMessageCommand,
  SQSClient,
} = require("@aws-sdk/client-sqs");
const config = require("./config");
const { resolveQueueUrl } = require("./sqs");

let sqsClient;
let submittedQueueUrlPromise;

async function publishSubmission(submission) {
  const queueUrl = await getSubmittedQueueUrl();

  await getSqsClient().send(
    new SendMessageCommand({
      QueueUrl: queueUrl,
      MessageBody: JSON.stringify(submission),
    }),
  );
}

// A cheap attribute read that proves the queue exists and that the IAM role
// can reach it.
async function checkReadiness() {
  const queueUrl = await getSubmittedQueueUrl();

  await getSqsClient().send(
    new GetQueueAttributesCommand({
      QueueUrl: queueUrl,
      AttributeNames: ["QueueArn"],
    }),
  );
}

function getSqsClient() {
  if (!sqsClient) {
    sqsClient = new SQSClient({ region: config.aws.region });
  }

  return sqsClient;
}

// Resolves the queue URL once and caches the promise. A failed lookup is
// cleared so the next call retries instead of reusing the rejection.
function getSubmittedQueueUrl() {
  if (!submittedQueueUrlPromise) {
    submittedQueueUrlPromise = resolveQueueUrl(
      getSqsClient(),
      config.aws.submittedQueueName,
    ).catch((error) => {
      submittedQueueUrlPromise = undefined;
      throw error;
    });
  }

  return submittedQueueUrlPromise;
}

async function close() {
  sqsClient?.destroy();
  sqsClient = undefined;
  submittedQueueUrlPromise = undefined;
}

module.exports = {
  checkReadiness,
  close,
  publishSubmission,
};
