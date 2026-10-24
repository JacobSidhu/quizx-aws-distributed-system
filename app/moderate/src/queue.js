// SQS workflow for reserving, releasing, approving, and rejecting submissions.
const crypto = require("crypto");
const {
  ChangeMessageVisibilityCommand,
  DeleteMessageCommand,
  GetQueueAttributesCommand,
  GetQueueUrlCommand,
  ReceiveMessageCommand,
  SendMessageCommand,
  SQSClient,
} = require("@aws-sdk/client-sqs");
const {
  ConfigurationError,
  ReviewTokenError,
  ValidationError,
} = require("./errors");
const {
  normalizeQuestion,
  questionValidationErrors,
  validatedQuestion,
} = require("./question");

// Unreadable bodies become an empty question rather than an exception, so the
// moderator still sees the message and can reject it.
function parseSubmission(body) {
  try {
    const payload = JSON.parse(body);

    // Accept direct SQS payloads and SNS-wrapped JSON without changing the
    // moderation contract.
    if (payload && typeof payload.Message === "string") {
      const message = JSON.parse(payload.Message);
      return message && typeof message === "object" ? message : {};
    }

    return payload && typeof payload === "object" ? payload : {};
  } catch (error) {
    return { question: "", options: [], answer: "", category: "" };
  }
}

function moderatorIdentity(auth = {}) {
  return {
    subject: auth.subject || "unknown",
    username: auth.username || auth.subject || "unknown",
  };
}

// Resolves both queue URLs at startup so a wrong queue name or a missing IAM
// permission stops the service before it accepts traffic.
async function resolveQueueUrls(client, queueConfig) {
  const [submittedQueue, moderatedQueue] = await Promise.all([
    client.send(
      new GetQueueUrlCommand({
        QueueName: queueConfig.submittedName,
      }),
    ),
    client.send(
      new GetQueueUrlCommand({
        QueueName: queueConfig.moderatedName,
      }),
    ),
  ]);

  if (!submittedQueue.QueueUrl) {
    throw new ConfigurationError(
      `SQS did not return a URL for ${queueConfig.submittedName}.`,
    );
  }

  if (!moderatedQueue.QueueUrl) {
    throw new ConfigurationError(
      `SQS did not return a URL for ${queueConfig.moderatedName}.`,
    );
  }

  return {
    ...queueConfig,
    submittedUrl: submittedQueue.QueueUrl,
    moderatedUrl: moderatedQueue.QueueUrl,
  };
}

// Moderation workflow built on SQS visibility timeouts. Receiving a message
// hides it from other moderators for the review window ("reservation");
// approving forwards it to the moderated queue; rejecting deletes it.
class ModerationQueue {
  constructor({ client, queueConfig, tokenManager, clock = () => new Date() }) {
    this.client = client;
    this.queueConfig = queueConfig;
    this.tokenManager = tokenManager;
    this.clock = clock;
  }

  async health() {
    await Promise.all([
      this.client.send(
        new GetQueueAttributesCommand({
          QueueUrl: this.queueConfig.submittedUrl,
          AttributeNames: ["QueueArn"],
        }),
      ),
      this.client.send(
        new GetQueueAttributesCommand({
          QueueUrl: this.queueConfig.moderatedUrl,
          AttributeNames: ["QueueArn"],
        }),
      ),
    ]);
  }

  // Reserves the next submission. The SQS receipt handle is sealed inside the
  // review token so it is never exposed to the browser in readable form.
  async receiveNext() {
    const result = await this.client.send(
      new ReceiveMessageCommand({
        QueueUrl: this.queueConfig.submittedUrl,
        MaxNumberOfMessages: 1,
        WaitTimeSeconds: this.queueConfig.waitTimeSeconds,
        VisibilityTimeout: this.queueConfig.visibilityTimeoutSeconds,
        MessageAttributeNames: ["All"],
        MessageSystemAttributeNames: ["SentTimestamp"],
      }),
    );
    const message = result.Messages?.[0];

    if (!message) {
      return null;
    }

    const source = parseSubmission(message.Body || "");
    const question = normalizeQuestion(source);
    const id = source.submissionId || source.id || message.MessageId;
    const reviewToken = this.tokenManager.seal(
      {
        id,
        messageId: message.MessageId,
        receiptHandle: message.ReceiptHandle,
        sourcePayloadHash: crypto
          .createHash("sha256")
          .update(message.Body || "")
          .digest("hex"),
      },
      this.queueConfig.visibilityTimeoutSeconds,
    );

    return {
      id,
      question,
      proposedCorrectAnswer: question.answer,
      validationErrors: questionValidationErrors(question),
      reviewToken,
      reservationExpiresInSeconds: this.queueConfig.visibilityTimeoutSeconds,
      submittedAt: message.Attributes?.SentTimestamp
        ? new Date(Number(message.Attributes.SentTimestamp)).toISOString()
        : null,
    };
  }

  // Confirms the token is genuine, unexpired, and belongs to this submission.
  validateReservation(id, token) {
    const reservation = this.tokenManager.open(token);

    if (
      !reservation.id ||
      reservation.id !== id ||
      !reservation.receiptHandle
    ) {
      throw new ReviewTokenError();
    }

    return reservation;
  }

  async approve({ id, token, input, auth }) {
    const reservation = this.validateReservation(id, token);
    const question = validatedQuestion(input);
    const moderatedAt = this.clock().toISOString();
    const payload = {
      schemaVersion: 4,
      id,
      ...question,
      moderation: {
        status: "approved",
        moderatedAt,
        moderator: moderatorIdentity(auth),
        sourceMessageId: reservation.messageId,
      },
    };
    const sendInput = {
      QueueUrl: this.queueConfig.moderatedUrl,
      MessageBody: JSON.stringify(payload),
      MessageAttributes: {
        moderationStatus: {
          DataType: "String",
          StringValue: "approved",
        },
        moderatorSubject: {
          DataType: "String",
          StringValue: payload.moderation.moderator.subject,
        },
      },
    };

    // FIFO queues require a group ID and use the deduplication ID to drop
    // repeated approvals of the same source message.
    if (this.queueConfig.moderatedUrl.endsWith(".fifo")) {
      sendInput.MessageGroupId = "moderated-questions";
      sendInput.MessageDeduplicationId = reservation.messageId || id;
    }

    const sent = await this.client.send(new SendMessageCommand(sendInput));

    // Delete only after the approved payload has been accepted downstream.
    await this.client.send(
      new DeleteMessageCommand({
        QueueUrl: this.queueConfig.submittedUrl,
        ReceiptHandle: reservation.receiptHandle,
      }),
    );

    return {
      id,
      status: "approved",
      moderatedAt,
      downstreamMessageId: sent.MessageId,
      question,
    };
  }

  async reject({ id, token, auth, reason }) {
    const reservation = this.validateReservation(id, token);
    const normalizedReason = typeof reason === "string" ? reason.trim() : "";

    if (normalizedReason.length > 500) {
      throw new ValidationError("The rejection reason is invalid.", [
        "The rejection reason must not exceed 500 characters.",
      ]);
    }

    await this.client.send(
      new DeleteMessageCommand({
        QueueUrl: this.queueConfig.submittedUrl,
        ReceiptHandle: reservation.receiptHandle,
      }),
    );

    return {
      id,
      status: "rejected",
      reason: normalizedReason,
      moderatedAt: this.clock().toISOString(),
      moderator: moderatorIdentity(auth),
    };
  }

  // Called periodically by the UI while a moderator is still reviewing. It
  // extends the SQS visibility timeout and issues a fresh token to match.
  async extendVisibility({ id, token }) {
    const reservation = this.validateReservation(id, token);

    await this.client.send(
      new ChangeMessageVisibilityCommand({
        QueueUrl: this.queueConfig.submittedUrl,
        ReceiptHandle: reservation.receiptHandle,
        VisibilityTimeout: this.queueConfig.visibilityTimeoutSeconds,
      }),
    );

    const { expiresAt, ...claims } = reservation;

    return {
      id,
      visibilityTimeoutSeconds: this.queueConfig.visibilityTimeoutSeconds,
      reviewToken: this.tokenManager.seal(
        claims,
        this.queueConfig.visibilityTimeoutSeconds,
      ),
    };
  }
}

function createQueueClient(awsConfig) {
  return new SQSClient({
    region: awsConfig.region,
  });
}

module.exports = {
  ModerationQueue,
  createQueueClient,
  parseSubmission,
  resolveQueueUrls,
};
