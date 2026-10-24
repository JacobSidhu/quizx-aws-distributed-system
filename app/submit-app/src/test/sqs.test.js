// Contract tests for resolving configured SQS queue names.
const test = require("node:test");
const assert = require("node:assert/strict");
const { resolveQueueUrl } = require("../sqs");

test("resolves an SQS queue URL from its queue name", async () => {
  const commands = [];
  const client = {
    async send(command) {
      commands.push(command);
      return {
        QueueUrl: "https://sqs.eu-west-2.amazonaws.com/123/submitted",
      };
    },
  };

  const queueUrl = await resolveQueueUrl(client, "quizx-dev-submit-app-queue");

  assert.equal(queueUrl, "https://sqs.eu-west-2.amazonaws.com/123/submitted");
  assert.equal(commands[0].constructor.name, "GetQueueUrlCommand");
  assert.equal(commands[0].input.QueueName, "quizx-dev-submit-app-queue");
});

test("rejects a missing URL in the SQS response", async () => {
  const client = { send: async () => ({}) };

  await assert.rejects(resolveQueueUrl(client, "missing-queue"), {
    message: "SQS did not return a URL for missing-queue.",
  });
});
