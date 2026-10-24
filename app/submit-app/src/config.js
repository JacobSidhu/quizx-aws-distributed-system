// Converts Submit App environment variables into its AWS runtime settings.
// Required values are checked at startup so a misconfigured service fails fast.
const DEFAULT_PORT = 4200;
const DEFAULT_CATEGORY_CACHE_FILE = "/var/lib/category/categories.json";

const config = {
  app: {
    name: "QuizX Submit App",
    version: "4.0.0",
    port: readNumber("PORT", DEFAULT_PORT),
  },
  questionApp: {
    baseUrl: readRequired("QUESTION_APP_BASE_URL").replace(/\/$/, ""),
  },
  categoryCache: {
    file: process.env.CATEGORY_CACHE_FILE || DEFAULT_CATEGORY_CACHE_FILE,
  },
  aws: {
    region: process.env.AWS_REGION || "eu-west-2",
    submittedQueueName: readRequired("SUBMITTED_QUESTIONS_QUEUE_NAME"),
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
