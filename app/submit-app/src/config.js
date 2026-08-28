const DEFAULT_PORT = 4200;
const DEFAULT_RABBITMQ_PORT = 5672;
const DEFAULT_CATEGORY_CACHE_FILE = '/var/lib/category/categories.json';

const config = {
  app: {
    name: 'QuizX Submit App',
    version: '2.0.0',
    port: readNumber('PORT', readNumber('HOST_PORT', DEFAULT_PORT))
  },
  questionApp: {
    baseUrl: readRequired('QUESTION_APP_BASE_URL').replace(/\/$/, '')
  },
  categoryCache: {
    file: process.env.CATEGORY_CACHE_FILE || DEFAULT_CATEGORY_CACHE_FILE
  },
  rabbitmq: {
    host: readRequired('RABBITMQ_HOST'),
    port: readNumber('RABBITMQ_PORT', DEFAULT_RABBITMQ_PORT),
    user: readRequired('RABBITMQ_USER'),
    password: readRequired('RABBITMQ_PASSWORD'),
    queue: readRequired('RABBITMQ_QUEUE')
  }
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
