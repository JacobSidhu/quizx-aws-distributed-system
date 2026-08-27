const DEFAULT_DB_PORT = 3306;
const DEFAULT_RABBITMQ_PORT = 5672;
const DEFAULT_PREFETCH = 5;
const DEFAULT_RECONNECT_DELAY_MS = 5000;

const config = {
  app: {
    name: 'QuizX ETL Consumer',
    version: '2.0.0',
    prefetch: readNumber('QUEUE_PREFETCH', DEFAULT_PREFETCH),
    reconnectDelayMs: readNumber('RECONNECT_DELAY_MS', DEFAULT_RECONNECT_DELAY_MS)
  },
  db: {
    host: readRequired('DB_HOST'),
    port: readNumber('DB_PORT', DEFAULT_DB_PORT),
    user: readRequired('DB_USER'),
    password: readRequired('DB_PASSWORD'),
    name: readRequired('DB_NAME')
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
