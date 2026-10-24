// Converts Question App environment variables into validated runtime settings.
const DEFAULT_PORT = 4000;
const DEFAULT_DB_PORT = 3306;
const DEFAULT_MAX_QUESTION_COUNT = 25;

const config = {
  app: {
    name: "QuizX Question App",
    version: "4.0.0",
    port: readNumber("PORT", DEFAULT_PORT),
    maxQuestionCount: readNumber(
      "MAX_QUESTION_COUNT",
      DEFAULT_MAX_QUESTION_COUNT,
    ),
  },
  db: {
    host: readRequired("DB_HOST"),
    port: readNumber("DB_PORT", DEFAULT_DB_PORT),
    user: readRequired("DB_USER"),
    password: readRequired("DB_PASSWORD"),
    name: readRequired("DB_NAME"),
  },
};

// Fails fast at startup so a missing setting is reported immediately rather
// than on the first database query.
function readRequired(name) {
  const value = process.env[name];

  if (!value) {
    throw new Error(`${name} is required`);
  }

  return value;
}

// Returns the default when the variable is unset and rejects anything that is
// not a positive integer.
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
