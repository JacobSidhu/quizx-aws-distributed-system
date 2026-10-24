// Small SQS helper kept separate so queue discovery can be tested in isolation.
const { GetQueueUrlCommand } = require("@aws-sdk/client-sqs");

// Looks up a queue URL from its name, so configuration only needs queue names
// and never hard-codes an AWS account ID.
async function resolveQueueUrl(client, queueName) {
  const response = await client.send(
    new GetQueueUrlCommand({
      QueueName: queueName,
    }),
  );

  if (!response.QueueUrl) {
    throw new Error(`SQS did not return a URL for ${queueName}.`);
  }

  return response.QueueUrl;
}

module.exports = { resolveQueueUrl };
