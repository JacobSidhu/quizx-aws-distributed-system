// Converts ETL Consumer environment variables into its SQS and RDS settings.
// Required values are checked at startup so a misconfigured worker fails fast.
const DEFAULT_DB_PORT = 3306;
const DEFAULT_SQS_MAX_MESSAGES = 5;
const DEFAULT_RETRY_DELAY_MS = 5000;
const DEFAULT_SQS_WAIT_TIME_SECONDS = 20;
const DEFAULT_SQS_VISIBILITY_TIMEOUT_SECONDS = 60;

const config = {
  app: {
    name: "QuizX ETL Consumer",
    version: "4.0.0",
    maxMessages: readNumber("SQS_MAX_MESSAGES", DEFAULT_SQS_MAX_MESSAGES),
    retryDelayMs: readNumber("RETRY_DELAY_MS", DEFAULT_RETRY_DELAY_MS),
  },
  db: {
    host: readRequired("DB_HOST"),
    port: readNumber("DB_PORT", DEFAULT_DB_PORT),
    user: readRequired("DB_USER"),
    password: readRequired("DB_PASSWORD"),
    name: readRequired("DB_NAME"),
  },
  aws: {
    region:
      process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || "eu-west-2",
    moderatedQueueName: readRequired("MODERATED_QUESTIONS_QUEUE_NAME"),
    waitTimeSeconds: readNumber(
      "SQS_WAIT_TIME_SECONDS",
      DEFAULT_SQS_WAIT_TIME_SECONDS,
    ),
    visibilityTimeoutSeconds: readNumber(
      "SQS_VISIBILITY_TIMEOUT_SECONDS",
      DEFAULT_SQS_VISIBILITY_TIMEOUT_SECONDS,
    ),
  },
};

function readRequired(name) {
  const value = process.env[name];

  if (!value) {
    throw new Error(`${name} is required`);
  }

  return value;
}

function readNumber(name, defaultValue) {
  const value = process.env[name];

  if (!value) {
    return defaultValue;
  }

  const number = Number(value);

  if (!Number.isInteger(number) || number < 1) {
    throw new Error(`${name} must be a positive integer`);
  }

  return number;
}

module.exports = config;
