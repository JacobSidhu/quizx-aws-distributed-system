const express = require('express');
const fs = require('fs/promises');
const path = require('path');

const app = express();
const PORT = process.env.PORT || process.env.HOST_PORT || 4200;
const DATA_FILE = path.join(__dirname, '../../data.json');

app.use(express.json());
app.use(express.static(path.join(__dirname, '../public')));

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '../public/index.html'));
});

app.get('/categories', async (req, res, next) => {
  try {
    const data = await readQuizData();

    res.status(200).json({
      categories: data.categories.map((item) => item.category)
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
      version: '1.0.0'
    },
    endpoints: {
      'GET /categories': 'Returns categories for the dropdown list.',
      'POST /submit': 'Writes a submitted question to app/data.json.',
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

app.post('/submit', async (req, res, next) => {
  try {
    const submission = normalizeSubmission(req.body);
    const validationError = validateSubmission(submission);

    if (validationError) {
      return res.status(400).json({ message: validationError });
    }

    const data = await readQuizData();
    const finalCategory = submission.newCategory || submission.category;
    const existingCategory = data.categories.find((item) => {
      return item.category.toLowerCase() === finalCategory.toLowerCase();
    });

    if (submission.newCategory && existingCategory) {
      return res.status(409).json({
        message: 'Category already exists. Choose it from the dropdown instead.'
      });
    }

    const categoryRecord = existingCategory || {
      category: finalCategory,
      questions: []
    };

    if (!Array.isArray(categoryRecord.questions)) {
      categoryRecord.questions = [];
    }

    const duplicateQuestion = categoryRecord.questions.some((item) => {
      return item.question.toLowerCase() === submission.question.toLowerCase();
    });

    if (duplicateQuestion) {
      return res.status(409).json({
        message: 'This question already exists in the selected category.'
      });
    }

    const questionRecord = {
      question: submission.question,
      options: submission.options,
      answer: submission.answer
    };

    categoryRecord.questions.push(questionRecord);

    if (!existingCategory) {
      data.categories.push(categoryRecord);
    }

    await writeQuizData(data);

    console.log('Submitted question saved to app/data.json:', {
      category: finalCategory,
      ...questionRecord
    });

    res.status(201).json({
      message: 'Question submitted successfully',
      category: finalCategory,
      question: questionRecord
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

async function readQuizData() {
  const fileContents = await fs.readFile(DATA_FILE, 'utf8');
  const data = JSON.parse(fileContents);

  if (!data || !Array.isArray(data.categories)) {
    throw new Error('Quiz data is not configured correctly');
  }

  return data;
}

async function writeQuizData(data) {
  const tempFile = `${DATA_FILE}.tmp`;

  await fs.writeFile(tempFile, `${JSON.stringify(data, null, 4)}\n`);
  await fs.rename(tempFile, DATA_FILE);
}

function normalizeText(value) {
  return typeof value === 'string' ? value.trim() : '';
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

  if (submission.options.length !== 4 || submission.options.some((option) => !option)) {
    return 'Exactly four answer options are required.';
  }

  if (new Set(submission.options.map((option) => option.toLowerCase())).size !== 4) {
    return 'Answer options must be unique.';
  }

  if (!submission.answer || !submission.options.includes(submission.answer)) {
    return 'Select one correct answer from the four options.';
  }

  return '';
}

app.listen(PORT, () => {
  console.log(`Submit app running on port ${PORT}`);
});
