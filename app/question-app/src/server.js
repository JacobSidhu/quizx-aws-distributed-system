const express = require('express');
const app = express();

const PORT = process.env.PORT || 3000;
const data = require('./data.json') // Using local JSON file for questions and categories;

app.get('/questions/:category', (req, res) => {
  const requestedCategory = req.params.category.toLowerCase();

  const selectedCategory = data.categories.find((item) => {
    return item.category.toLowerCase() === requestedCategory;
  });

  if (!selectedCategory) {
    return res.status(404).json({
      message: 'Category not found'
    });
  }

  const randomIndex = Math.floor(Math.random() * selectedCategory.questions.length);
  const randomQuestion = selectedCategory.questions[randomIndex];

  res.json({
    category: selectedCategory.category,
    question: randomQuestion.question,
    options: randomQuestion.options
  });
});

app.get('/categories', (req, res) => {
  const categories = data.categories.map((item) => item.category);

  res.json({
    categories: categories
  });
});

// Start the server
app.listen(PORT, () => {
  console.log(`Question app running on port ${PORT}`);
});