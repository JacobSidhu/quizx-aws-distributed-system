// Loads Moderator Service settings and validates that every required value is
// present before the service starts.
const { ConfigurationError } = require("./errors");

// Reads an integer setting and enforces the range AWS or the app allows.
function integerFromEnvironment(name, fallback, minimum, maximum) {
  const value = Number.parseInt(process.env[name] || `${fallback}`, 10);

  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new ConfigurationError(
      `${name} must be an integer between ${minimum} and ${maximum}.`,
    );
  }

  return value;
}

const config = {
  app: {
    name: "QuizX Moderator Service",
    version: "4.0.0",
    environment: process.env.NODE_ENV || "development",
    port: integerFromEnvironment("PORT", 4300, 1, 65535),
  },
  aws: {
    region: process.env.AWS_REGION || "eu-west-2",
  },
  queues: {
    submittedName: process.env.SUBMITTED_QUESTIONS_QUEUE_NAME || "",
    moderatedName: process.env.MODERATED_QUESTIONS_QUEUE_NAME || "",
    waitTimeSeconds: integerFromEnvironment(
      "QUEUE_WAIT_TIME_SECONDS",
      20,
      0,
      20,
    ),
    visibilityTimeoutSeconds: integerFromEnvironment(
      "QUEUE_VISIBILITY_TIMEOUT_SECONDS",
      300,
      30,
      43200,
    ),
  },
  categories: {
    baseUrl: (process.env.QUESTION_APP_BASE_URL || "").replace(/\/$/, ""),
    timeoutMs: integerFromEnvironment(
      "CATEGORY_REQUEST_TIMEOUT_MS",
      3000,
      100,
      30000,
    ),
  },
  auth: {
    userPoolId: process.env.COGNITO_USER_POOL_ID || "",
    clientId: process.env.COGNITO_CLIENT_ID || "",
    moderatorGroup: process.env.COGNITO_MODERATOR_GROUP || "quizx-moderators",
  },
  reviewTokenSecret: process.env.REVIEW_TOKEN_SECRET || "",
};

function validateRuntimeConfig(runtimeConfig = config) {
  const missing = [];

  if (!runtimeConfig.queues.submittedName) {
    missing.push("SUBMITTED_QUESTIONS_QUEUE_NAME");
  }

  if (!runtimeConfig.queues.moderatedName) {
    missing.push("MODERATED_QUESTIONS_QUEUE_NAME");
  }

  if (!runtimeConfig.categories.baseUrl) {
    missing.push("QUESTION_APP_BASE_URL");
  }

  if (
    !runtimeConfig.reviewTokenSecret ||
    runtimeConfig.reviewTokenSecret.length < 32
  ) {
    missing.push("REVIEW_TOKEN_SECRET (at least 32 characters)");
  }

  if (!runtimeConfig.auth.userPoolId) {
    missing.push("COGNITO_USER_POOL_ID");
  }

  if (!runtimeConfig.auth.clientId) {
    missing.push("COGNITO_CLIENT_ID");
  }

  if (missing.length > 0) {
    throw new ConfigurationError(
      `Missing required configuration: ${missing.join(", ")}.`,
    );
  }
}

module.exports = { config, validateRuntimeConfig };
