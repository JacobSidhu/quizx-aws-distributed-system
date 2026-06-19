const amqp = require('amqplib');
const config = require('./config');
const mysql = require('./db');

let shuttingDown = false;
let rabbitConnection;
let rabbitChannel;

async function start() {
  while (!shuttingDown) {
    try {
      await connectAndConsume();
      return;
    } catch (error) {
      console.error('ETL consumer startup failed:', error.message);
      await wait(config.app.reconnectDelayMs);
    }
  }
}

async function connectAndConsume() {
  const rabbitUrl = buildRabbitUrl();

  await mysql.query('SELECT 1');

  rabbitConnection = await amqp.connect(rabbitUrl);
  rabbitConnection.on('close', handleRabbitDisconnect);
  rabbitConnection.on('error', (error) => {
    console.error('RabbitMQ connection error:', error.message);
  });

  rabbitChannel = await rabbitConnection.createChannel();
  await rabbitChannel.assertQueue(config.rabbitmq.queue, {
    durable: true
  });
  rabbitChannel.prefetch(config.app.prefetch);

  await rabbitChannel.consume(config.rabbitmq.queue, handleMessage, {
    noAck: false
  });

  console.log(`${config.app.name} consuming ${config.rabbitmq.queue}`);
}

async function handleMessage(message) {
  if (!message) {
    return;
  }

  try {
    const submission = parseSubmission(message.content);
    await saveSubmission(submission);
    rabbitChannel.ack(message);

    console.log('Submitted question loaded into MySQL:', {
      category: submission.finalCategory,
      question: submission.question
    });
  } catch (error) {
    if (error.isValidationError || error.isDuplicateQuestion) {
      console.error('Discarding submitted question message:', error.message);
      rabbitChannel.nack(message, false, false);
      return;
    }

    console.error('Failed to process submitted question message:', error);
    rabbitChannel.nack(message, false, true);
  }
}

function parseSubmission(content) {
  let body;

  try {
    body = JSON.parse(content.toString('utf8'));
  } catch (error) {
    throw validationError('Message body must be valid JSON.');
  }

  const submission = normalizeSubmission(body);
  const validationMessage = validateSubmission(submission);

  if (validationMessage) {
    throw validationError(validationMessage);
  }

  return {
    ...submission,
    finalCategory: submission.newCategory || submission.category
  };
}

async function saveSubmission(submission) {
  const connection = await mysql.getConnection();

  try {
    await connection.beginTransaction();

    const [existingCategories] = await connection.query(
      'SELECT id, name FROM categories WHERE LOWER(name) = LOWER(?) LIMIT 1',
      [submission.finalCategory]
    );
    const existingCategory = existingCategories[0];

    if (submission.newCategory && existingCategory) {
      throw validationError('Category already exists. Choose it from the dropdown instead.');
    }

    let categoryId = existingCategory?.id;

    if (!categoryId) {
      const [categoryResult] = await connection.query(
        'INSERT INTO categories (name) VALUES (?)',
        [submission.finalCategory]
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
      [categoryId, submission.question]
    );

    if (duplicateQuestions.length > 0) {
      const error = new Error('This question already exists in the selected category.');
      error.isDuplicateQuestion = true;
      throw error;
    }

    const [questionResult] = await connection.query(
      'INSERT INTO questions (category_id, question_text, answer) VALUES (?, ?, ?)',
      [categoryId, submission.question, submission.answer]
    );
    const questionId = questionResult.insertId;
    const optionRows = submission.options.map((option) => {
      return [questionId, option, option === submission.answer];
    });

    await connection.query(
      'INSERT INTO question_options (question_id, option_text, is_correct) VALUES ?',
      [optionRows]
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
    answer: normalizeText(body.answer)
  };
}

function validateSubmission(submission) {
  const categoryCount = [
    submission.category,
    submission.newCategory
  ].filter(Boolean).length;

  if (!submission.question) {
    return 'Question is required.';
  }

  if (categoryCount !== 1) {
    return 'Choose an existing category or add one new category.';
  }

  if (
    submission.options.length !== 4 ||
    submission.options.some((option) => !option)
  ) {
    return 'Exactly four answer options are required.';
  }

  const uniqueOptions = new Set(
    submission.options.map((option) => option.toLowerCase())
  );

  if (uniqueOptions.size !== 4) {
    return 'Answer options must be unique.';
  }

  if (!submission.answer || !submission.options.includes(submission.answer)) {
    return 'Select one correct answer from the four options.';
  }

  return '';
}

function normalizeText(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function validationError(message) {
  const error = new Error(message);
  error.isValidationError = true;
  return error;
}

function buildRabbitUrl() {
  const user = encodeURIComponent(config.rabbitmq.user);
  const password = encodeURIComponent(config.rabbitmq.password);

  return `amqp://${user}:${password}@${config.rabbitmq.host}:${config.rabbitmq.port}`;
}

function handleRabbitDisconnect() {
  if (shuttingDown) {
    return;
  }

  console.error('RabbitMQ connection closed. Reconnecting...');
  rabbitConnection = undefined;
  rabbitChannel = undefined;
  setTimeout(start, config.app.reconnectDelayMs);
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function shutdown() {
  shuttingDown = true;

  try {
    if (rabbitChannel) {
      await rabbitChannel.close();
    }

    if (rabbitConnection) {
      await rabbitConnection.close();
    }

    await mysql.end();
    process.exit(0);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

start();
