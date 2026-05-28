const DEFAULT_PORT = 4200;

const config = {
  app: {
    name: 'QuizX Submit App',
    version: '1.0.0',
    port: readNumber('PORT', readNumber('HOST_PORT', DEFAULT_PORT))
  },
  db: {
    host: readRequired('DB_HOST'),
    port: readNumber('DB_PORT', 3306),
    user: readRequired('DB_USER'),
    password: readRequired('DB_PASSWORD'),
    name: readRequired('DB_NAME')
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
