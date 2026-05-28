const express = require('express');
const app = express();

const PORT = process.env.PORT || 3000;
const data = require('./data.json');

app.get('/questions/:category', (req, res) => {
  const requestedCategory = req.params.category.toLowerCase();

  const selectedCategory = data.categories.find((item) => {
    return item.category.toLowerCase() === requestedCategory;
  });

  if (!selectedCategory) {
    return res.status(404).json({
      message: 'Category not found',
      availableCategories: data.categories.map((item) => item.category)
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

  res.json({
    category: selectedCategory.category,
    questions: safeQuestions
  });
});

app.get('/categories', (req, res) => {
  const categories = data.categories.map((item) => item.category);

  res.json({
    categories: categories
  });
});

app.listen(PORT, () => {
  console.log(`Question app running on port ${PORT}`);
});