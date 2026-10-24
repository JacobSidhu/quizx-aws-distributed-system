// Background worker that long-polls the moderated-questions SQS queue and
// stores each approved question in Amazon RDS for MySQL. It is the only
// component in QuizX with write access to the question tables.
const {
  ChangeMessageVisibilityCommand,
  DeleteMessageCommand,
  ReceiveMessageCommand,
  SQSClient,
} = require("@aws-sdk/client-sqs");
const config = require("./config");
const database = require("./db");
const { resolveQueueUrl } = require("./sqs");

let shuttingDown = false;
let sqsClient;
let moderatedQueueUrlPromise;

// Keeps the worker alive across transient failures. If RDS or SQS is
// unreachable, it waits RETRY_DELAY_MS and tries again rather than exiting.
async function start() {
  while (!shuttingDown) {
    try {
      await database.query("SELECT 1");

      console.log(`${config.app.name} consuming approved questions from SQS`);
      await consumeSqs();
    } catch (error) {
      console.error("ETL consumer startup failed:", error.message);
      await wait(config.app.retryDelayMs);
    }
  }
}

// Long-polls the queue. The values are capped at the SQS limits (10 messages,
// 20-second wait) in case the environment asks for more.
async function consumeSqs() {
  sqsClient ||= new SQSClient({
    region: config.aws.region,
  });
  const moderatedQueueUrl = await getModeratedQueueUrl();

  while (!shuttingDown) {
    const response = await sqsClient.send(
      new ReceiveMessageCommand({
        QueueUrl: moderatedQueueUrl,
        MaxNumberOfMessages: Math.min(config.app.maxMessages, 10),
        WaitTimeSeconds: Math.min(config.aws.waitTimeSeconds, 20),
        VisibilityTimeout: config.aws.visibilityTimeoutSeconds,
      }),
    );

    for (const message of response.Messages || []) {
      await handleSqsMessage(message);
    }
  }
}

// Processes one message:
// - stored successfully: delete it from the queue;
// - invalid or duplicate: delete it, because retrying cannot succeed;
// - any other failure: make it visible again straight away so it is retried.
async function handleSqsMessage(message) {
  try {
    const submission = parseSubmission(Buffer.from(message.Body || "", "utf8"));
    await saveSubmission(submission);
    await sqsClient.send(
      new DeleteMessageCommand({
        QueueUrl: await getModeratedQueueUrl(),
        ReceiptHandle: message.ReceiptHandle,
      }),
    );

    console.log("Approved question stored in Amazon RDS:", {
      category: submission.finalCategory,
    });
  } catch (error) {
    if (error.isValidationError || error.isDuplicateQuestion) {
      console.error("Discarding invalid approved question:", error.message);
      await deleteSqsMessage(message);
      return;
    }

    console.error("Failed to process approved question:", error);
    await sqsClient.send(
      new ChangeMessageVisibilityCommand({
        QueueUrl: await getModeratedQueueUrl(),
        ReceiptHandle: message.ReceiptHandle,
        VisibilityTimeout: 0,
      }),
    );
  }
}

async function deleteSqsMessage(message) {
  await sqsClient.send(
    new DeleteMessageCommand({
      QueueUrl: await getModeratedQueueUrl(),
      ReceiptHandle: message.ReceiptHandle,
    }),
  );
}

// Resolves the queue URL once and caches the promise. A failed lookup is
// cleared so the next call retries instead of reusing the rejection.
function getModeratedQueueUrl() {
  if (!moderatedQueueUrlPromise) {
    moderatedQueueUrlPromise = resolveQueueUrl(
      sqsClient,
      config.aws.moderatedQueueName,
    ).catch((error) => {
      moderatedQueueUrlPromise = undefined;
      throw error;
    });
  }

  return moderatedQueueUrlPromise;
}

// Parses and validates a message body. The message has already been approved,
// but the worker validates it again because it is the last check before RDS.
function parseSubmission(content) {
  let body;

  try {
    body = JSON.parse(content.toString("utf8"));
  } catch (error) {
    throw validationError("Message body must be valid JSON.");
  }

  const submission = normalizeSubmission(body);
  const validationMessage = validateSubmission(submission);

  if (validationMessage) {
    throw validationError(validationMessage);
  }

  return {
    ...submission,
    finalCategory: submission.newCategory || submission.category,
  };
}

// Writes the category (if new), the question, and its four options in one
// transaction, so a failure part-way through leaves no partial records. The
// duplicate check matters because SQS can deliver the same message twice.
async function saveSubmission(submission) {
  const connection = await database.getConnection();

  try {
    await connection.beginTransaction();

    const [existingCategories] = await connection.query(
      "SELECT id, name FROM categories WHERE LOWER(name) = LOWER(?) LIMIT 1",
      [submission.finalCategory],
    );
    const existingCategory = existingCategories[0];

    if (submission.newCategory && existingCategory) {
      throw validationError(
        "Category already exists. Choose it from the dropdown instead.",
      );
    }

    let categoryId = existingCategory?.id;

    if (!categoryId) {
      const [categoryResult] = await connection.query(
        "INSERT INTO categories (name) VALUES (?)",
        [submission.finalCategory],
      );

      categoryId = categoryResult.insertId;
    }

    const [duplicateQuestions] = await connection.query(
      `
        SELECT id
        FROM questions
        WHERE category_id = ?
          AND LOWER(question_text) = LOWER(?)
        LIMIT 1
      `,
      [categoryId, submission.question],
    );

    if (duplicateQuestions.length > 0) {
      const error = new Error(
        "This question already exists in the selected category.",
      );
      error.isDuplicateQuestion = true;
      throw error;
    }

    const [questionResult] = await connection.query(
      "INSERT INTO questions (category_id, question_text, answer) VALUES (?, ?, ?)",
      [categoryId, submission.question, submission.answer],
    );
    const questionId = questionResult.insertId;
    const optionRows = submission.options.map((option) => {
      return [questionId, option, option === submission.answer];
    });

    await connection.query(
      "INSERT INTO question_options (question_id, option_text, is_correct) VALUES ?",
      [optionRows],
    );
    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

function normalizeSubmission(body) {
  const options = Array.isArray(body.options)
    ? body.options.map(normalizeText)
    : [];

  return {
    question: normalizeText(body.question),
    category: normalizeText(body.category),
    newCategory: normalizeText(body.newCategory),
    options,
    answer: normalizeText(body.answer),
  };
}

function validateSubmission(submission) {
  const categoryCount = [submission.category, submission.newCategory].filter(
    Boolean,
  ).length;

  if (!submission.question) {
    return "Question is required.";
  }

  if (categoryCount !== 1) {
    return "Choose an existing category or add one new category.";
  }

  if (
    submission.options.length !== 4 ||
    submission.options.some((option) => !option)
  ) {
    return "Exactly four answer options are required.";
  }

  const uniqueOptions = new Set(
    submission.options.map((option) => option.toLowerCase()),
  );

  if (uniqueOptions.size !== 4) {
    return "Answer options must be unique.";
  }

  if (!submission.answer || !submission.options.includes(submission.answer)) {
    return "Select one correct answer from the four options.";
  }

  return "";
}

function normalizeText(value) {
  return typeof value === "string" ? value.trim() : "";
}

// Marks an error as permanent so handleSqsMessage discards the message.
function validationError(message) {
  const error = new Error(message);
  error.isValidationError = true;
  return error;
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Stops polling and closes the SQS client and connection pool on SIGTERM. Any
// message still in flight becomes visible again after its timeout.
async function shutdown() {
  shuttingDown = true;

  try {
    if (sqsClient) {
      sqsClient.destroy();
    }

    moderatedQueueUrlPromise = undefined;

    await database.end();
    process.exit(0);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

start();
