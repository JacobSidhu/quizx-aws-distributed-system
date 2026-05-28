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

app.get('/docs', (req, res) => {
  res.status(200).json({
    openapi: '3.0.0',
    info: {
      title: 'QuizX Question App API',
      version: config.app.version
    },
    endpoints: {
      'GET /health': 'Returns process health.',
      'GET /ready': 'Checks database connectivity.',
      'GET /categories': 'Returns all available quiz categories.',
      'GET /questions/:category?count=5': 'Returns random questions without answers.'
    },
    limits: {
      maxQuestionCount: config.app.maxQuestionCount
    }
  });
});

app.get('/questions/:category', async (req, res, next) => {
  try {
    const requestedCategory = normalizeText(req.params.category).toLowerCase();

    if (!requestedCategory) {
      return res.status(400).json({
        message: 'Category is required'
      });
    }

    const [categories] = await mysql.query(
      'SELECT id, name FROM categories WHERE LOWER(name) = LOWER(?) LIMIT 1',
      [requestedCategory]
    );
    const selectedCategory = categories[0];

    if (!selectedCategory) {
      return res.status(404).json({
        message: 'Category not found',
        availableCategories: await getCategoryNames()
      });
    }

    const count = normalizeQuestionCount(req.query.count);

    const [questions] = await mysql.query(
      `
        SELECT id, question_text
        FROM questions
        WHERE category_id = ?
        ORDER BY RAND()
        LIMIT ?
      `,
      [selectedCategory.id, count]
    );

    if (questions.length === 0) {
      return res.status(404).json({
        message: 'No questions found for this category'
      });
    }

    const questionIds = questions.map((question) => question.id);
    const optionPlaceholders = questionIds.map(() => '?').join(', ');
    const [options] = await mysql.query(
      `
        SELECT question_id, option_text
        FROM question_options
        WHERE question_id IN (${optionPlaceholders})
        ORDER BY id
      `,
      questionIds
    );
    const optionsByQuestionId = options.reduce((result, option) => {
      result[option.question_id] = result[option.question_id] || [];
      result[option.question_id].push(option.option_text);

      return result;
    }, {});

    const safeQuestions = questions.map((question) => {
      return {
        question: question.question_text,
        options: optionsByQuestionId[question.id] || []
      };
    });

    res.status(200).json({
      category: selectedCategory.name,
      requestedCount: count,
      returnedCount: safeQuestions.length,
      questions: safeQuestions
    });
  } catch (error) {
    next(error);
  }
});

app.get('/categories', async (req, res, next) => {
  try {
    res.status(200).json({
      categories: await getCategoryNames()
    });
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

async function getCategoryNames() {
  const [categories] = await mysql.query(
    'SELECT name FROM categories ORDER BY name'
  );

  return categories.map((item) => item.name);
}

function normalizeQuestionCount(value) {
  const count = parseInt(value, 10);

  if (!count || count < 1) {
    return 1;
  }

  return Math.min(count, config.app.maxQuestionCount);
}

function normalizeText(value) {
  return typeof value === 'string' ? value.trim() : '';
}

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

const server = app.listen(config.app.port, () => {
  console.log(`${config.app.name} running on port ${config.app.port}`);
});

process.on('SIGINT', () => shutdown(server));
process.on('SIGTERM', () => shutdown(server));
