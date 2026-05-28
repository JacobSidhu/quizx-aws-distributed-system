const express = require('express');
const path = require('path');
const config = require('./config');
const mysql = require('./db');

const app = express();
const PUBLIC_DIR = path.join(__dirname, '../public');

app.use(express.json());
app.use(express.static(PUBLIC_DIR));

app.get('/', (req, res) => {
  res.sendFile(path.join(PUBLIC_DIR, 'index.html'));
});

app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    app: config.app.name,
    version: config.app.version
  });
});

app.get('/ready', checkDatabaseReadiness);
app.get('/db/health', checkDatabaseReadiness);

app.get('/categories', async (req, res, next) => {
  try {
    res.status(200).json({
      categories: await getCategoryNames()
    });
  } catch (error) {
    next(error);
  }
});

app.get('/docs', (req, res) => {
  res.status(200).json({
    openapi: '3.0.0',
    info: {
      title: 'QuizX Submit App API',
      version: config.app.version
    },
    endpoints: {
      'GET /health': 'Returns process health.',
      'GET /ready': 'Checks database connectivity.',
      'GET /categories': 'Returns categories for the dropdown list.',
      'POST /submit': 'Writes a submitted question to MySQL.',
      'GET /docs': 'Returns this API documentation.'
    },
    submitPayload: {
      category: 'Science',
      newCategory: '',
      question: 'What is the chemical symbol for gold?',
      options: ['Au', 'Ag', 'Fe', 'Pb'],
      answer: 'Au'
    }
  });
});

async function checkDatabaseReadiness(req, res, next) {
  try {
    await mysql.query('SELECT 1');

    res.status(200).json({
      status: 'ok',
      database: config.db.name
    });
  } catch (error) {
    next(error);
  }
}

app.post('/submit', async (req, res, next) => {
  try {
    const submission = normalizeSubmission(req.body);
    const validationError = validateSubmission(submission);

    if (validationError) {
      return res.status(400).json({ message: validationError });
    }

    const finalCategory = submission.newCategory || submission.category;
    const connection = await mysql.getConnection();

    try {
      await connection.beginTransaction();

      const [existingCategories] = await connection.query(
        'SELECT id, name FROM categories WHERE LOWER(name) = LOWER(?) LIMIT 1',
        [finalCategory]
      );
      const existingCategory = existingCategories[0];

      if (submission.newCategory && existingCategory) {
        await connection.rollback();

        return res.status(409).json({
          message: 'Category already exists. Choose it from the dropdown instead.'
        });
      }

      let categoryId = existingCategory?.id;

      if (!categoryId) {
        const [categoryResult] = await connection.query(
          'INSERT INTO categories (name) VALUES (?)',
          [finalCategory]
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
        await connection.rollback();

        return res.status(409).json({
          message: 'This question already exists in the selected category.'
        });
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

      const questionRecord = {
        question: submission.question,
        options: submission.options,
        answer: submission.answer
      };

      console.log('Submitted question saved to MySQL:', {
        category: finalCategory,
        ...questionRecord
      });

      res.status(201).json({
        message: 'Question submitted successfully',
        category: finalCategory,
        question: questionRecord
      });
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  } catch (error) {
    next(error);
  }
});

app.use((req, res) => {
  res.status(404).json({
    message: 'Route not found'
  });
});

app.use((error, req, res, next) => {
  console.error(error);

  res.status(500).json({
    message: 'Internal server error'
  });
});

async function shutdown(server) {
  server.close(async () => {
    try {
      await mysql.end();
      process.exit(0);
    } catch (error) {
      console.error(error);
      process.exit(1);
    }
  });
}

function normalizeText(value) {
  return typeof value === 'string' ? value.trim() : '';
}

async function getCategoryNames() {
  const [categories] = await mysql.query(
    'SELECT name FROM categories ORDER BY name'
  );

  return categories.map((item) => item.name);
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

const server = app.listen(config.app.port, () => {
  console.log(`${config.app.name} running on port ${config.app.port}`);
});

process.on('SIGINT', () => shutdown(server));
process.on('SIGTERM', () => shutdown(server));
