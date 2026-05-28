const express = require('express');
const path = require('path');

const app = express();

const PORT = process.env.PORT || 3000;
const data = require('../../data.json');

app.use(express.json());

// Serve frontend files from public folder
app.use(express.static(path.join(__dirname, '../public')));

// Root page
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '../public/index.html'));
});

/**
 * GET /questions/:category
 *
 * Returns one or more random questions from a selected category.
 */
app.get('/questions/:category', (req, res, next) => {
  try {
    if (!data || !Array.isArray(data.categories)) {
      return res.status(500).json({
        message: 'Question data is not configured correctly'
      });
    }

    const requestedCategory = req.params.category?.toLowerCase();

    if (!requestedCategory) {
      return res.status(400).json({
        message: 'Category is required'
      });
    }

    const selectedCategory = data.categories.find((item) => {
      return item.category.toLowerCase() === requestedCategory;
    });

    if (!selectedCategory) {
      return res.status(404).json({
        message: 'Category not found',
        availableCategories: data.categories.map((item) => item.category)
      });
    }

    if (
      !Array.isArray(selectedCategory.questions) ||
      selectedCategory.questions.length === 0
    ) {
      return res.status(404).json({
        message: 'No questions found for this category'
      });
    }

    let count = parseInt(req.query.count, 10);

    if (!count || count < 1) {
      count = 1;
    }

    const finalCount = Math.min(count, selectedCategory.questions.length);

    const shuffledQuestions = [...selectedCategory.questions].sort(() => {
      return Math.random() - 0.5;
    });

    const selectedQuestions = shuffledQuestions.slice(0, finalCount);

    const safeQuestions = selectedQuestions.map((question) => {
      return {
        question: question.question,
        options: question.options
      };
    });

    res.status(200).json({
      category: selectedCategory.category,
      requestedCount: count,
      returnedCount: safeQuestions.length,
      questions: safeQuestions
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /categories
 *
 * Returns all available quiz categories.
 */
app.get('/categories', (req, res, next) => {
  try {
    if (!data || !Array.isArray(data.categories)) {
      return res.status(500).json({
        message: 'Category data is not configured correctly'
      });
    }

    const categories = data.categories.map((item) => item.category);

    res.status(200).json({
      categories: categories
    });
  } catch (error) {
    next(error);
  }
});

// Handle unknown routes
app.use((req, res) => {
  res.status(404).json({
    message: 'Route not found'
  });
});

// Global error handler
app.use((error, req, res, next) => {
  console.error(error);

  res.status(500).json({
    message: 'Internal server error'
  });
});

app.listen(PORT, () => {
  console.log(`Question app running on port ${PORT}`);
});
