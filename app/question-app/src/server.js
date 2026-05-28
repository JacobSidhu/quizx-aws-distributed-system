const express = require('express');
const app = express();

// Use environment port if available, otherwise use 3000
const PORT = process.env.PORT || 3000;

// Import question data from local JSON file
const data = require('./data.json');

/**
 * GET /questions/:category
 *
 * Returns one or more random questions from a selected category.
 *
 * Example:
 * /questions/Science
 * /questions/Science?count=3
 */
app.get('/questions/:category', (req, res) => {
  // Read category from URL parameter
  const requestedCategory = req.params.category.toLowerCase();

  // Find matching category from data.json
  const selectedCategory = data.categories.find((item) => {
    return item.category.toLowerCase() === requestedCategory;
  });

  // Return 404 if category does not exist
  if (!selectedCategory) {
    return res.status(404).json({
      message: 'Category not found',
      availableCategories: data.categories.map((item) => item.category)
    });
  }

  // Read count from query string, for example: ?count=3
  let count = parseInt(req.query.count, 10);

  // Default count to 1 if not provided or invalid
  if (!count || count < 1) {
    count = 1;
  }

  // Prevent requesting more questions than available
  const finalCount = Math.min(count, selectedCategory.questions.length);

  // Shuffle questions randomly
  const shuffledQuestions = [...selectedCategory.questions].sort(() => {
    return Math.random() - 0.5;
  });

  // Select requested number of questions
  const selectedQuestions = shuffledQuestions.slice(0, finalCount);

  // Remove answers before sending response
  const safeQuestions = selectedQuestions.map((question) => {
    return {
      question: question.question,
      options: question.options
    };
  });

  // Send response
  res.json({
    category: selectedCategory.category,
    questions: safeQuestions
  });
});

/**
 * GET /categories
 *
 * Returns all available quiz categories.
 */
app.get('/categories', (req, res) => {
  const categories = data.categories.map((item) => item.category);

  res.json({
    categories: categories
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`Question app running on port ${PORT}`);
});