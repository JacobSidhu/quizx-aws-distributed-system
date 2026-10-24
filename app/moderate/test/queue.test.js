// Unit tests for SQS reservation and moderation transitions.
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  ModerationQueue,
  parseSubmission,
  resolveQueueUrls,
} = require("../src/queue");
const { createReviewTokenManager } = require("../src/review-token");

const queueConfig = {
  submittedUrl: "http://sqs.local/submitted-questions",
  moderatedUrl: "http://sqs.local/moderated-questions",
  waitTimeSeconds: 0,
  visibilityTimeoutSeconds: 300,
};

function createFakeClient(responses = []) {
  const commands = [];

  return {
    commands,
    async send(command) {
      commands.push(command);
      return responses.shift() || {};
    },
  };
}

function createQueue(client) {
  return new ModerationQueue({
    client,
    queueConfig,
    tokenManager: createReviewTokenManager(
      "local-test-secret-that-is-long-enough",
      () => Date.parse("2026-01-01T00:00:00.000Z"),
    ),
    clock: () => new Date("2026-01-01T00:00:00.000Z"),
  });
}

test("parses direct and SNS-wrapped submissions", () => {
  const submission = { question: "Q", options: ["A", "B", "C", "D"] };

  assert.deepEqual(parseSubmission(JSON.stringify(submission)), submission);
  assert.deepEqual(
    parseSubmission(JSON.stringify({ Message: JSON.stringify(submission) })),
    submission,
  );
});

test("resolves both queue URLs from their configured names", async () => {
  const client = createFakeClient([
    { QueueUrl: "https://sqs.eu-west-2.amazonaws.com/123/submitted" },
    { QueueUrl: "https://sqs.eu-west-2.amazonaws.com/123/moderated" },
  ]);

  const resolved = await resolveQueueUrls(client, {
    submittedName: "quizx-dev-submit-app-queue",
    moderatedName: "quizx-dev-moderate-queue",
    waitTimeSeconds: 20,
    visibilityTimeoutSeconds: 300,
  });

  assert.equal(
    resolved.submittedUrl,
    "https://sqs.eu-west-2.amazonaws.com/123/submitted",
  );
  assert.equal(
    resolved.moderatedUrl,
    "https://sqs.eu-west-2.amazonaws.com/123/moderated",
  );
  assert.deepEqual(
    client.commands.map((command) => command.constructor.name),
    ["GetQueueUrlCommand", "GetQueueUrlCommand"],
  );
  assert.deepEqual(
    client.commands.map((command) => command.input.QueueName),
    ["quizx-dev-submit-app-queue", "quizx-dev-moderate-queue"],
  );
});

test("rejects startup when SQS does not return a queue URL", async () => {
  const client = createFakeClient([
    {},
    { QueueUrl: "https://sqs.eu-west-2.amazonaws.com/123/moderated" },
  ]);

  await assert.rejects(
    resolveQueueUrls(client, {
      submittedName: "missing-submitted-queue",
      moderatedName: "quizx-dev-moderate-queue",
    }),
    {
      code: "CONFIGURATION_ERROR",
      message: "SQS did not return a URL for missing-submitted-queue.",
    },
  );
});

test("returns null when no submitted question is available", async () => {
  const client = createFakeClient([{ Messages: [] }]);
  const result = await createQueue(client).receiveNext();

  assert.equal(result, null);
  assert.equal(client.commands[0].constructor.name, "ReceiveMessageCommand");
});

test("approval publishes before deleting the source message", async () => {
  const client = createFakeClient([{ MessageId: "moderated-1" }, {}]);
  const queue = createQueue(client);
  const token = queue.tokenManager.seal(
    {
      id: "submission-1",
      messageId: "source-message-1",
      receiptHandle: "receipt-1",
    },
    300,
  );

  const result = await queue.approve({
    id: "submission-1",
    token,
    auth: { subject: "moderator-1", username: "mod" },
    input: {
      question: "Capital of France?",
      options: ["Paris", "Rome", "Berlin", "Madrid"],
      answer: "Paris",
      category: "Geography",
    },
  });

  assert.equal(result.status, "approved");
  assert.deepEqual(
    client.commands.map((command) => command.constructor.name),
    ["SendMessageCommand", "DeleteMessageCommand"],
  );

  const body = JSON.parse(client.commands[0].input.MessageBody);
  assert.equal(body.moderation.status, "approved");
  assert.equal(body.moderation.moderator.subject, "moderator-1");
});

test("rejection deletes without publishing downstream", async () => {
  const client = createFakeClient([{}]);
  const queue = createQueue(client);
  const token = queue.tokenManager.seal(
    {
      id: "submission-1",
      receiptHandle: "receipt-1",
    },
    300,
  );

  const result = await queue.reject({
    id: "submission-1",
    token,
    reason: "Duplicate",
    auth: { subject: "moderator-1" },
  });

  assert.equal(result.status, "rejected");
  assert.equal(result.reason, "Duplicate");
  assert.deepEqual(
    client.commands.map((command) => command.constructor.name),
    ["DeleteMessageCommand"],
  );
});
