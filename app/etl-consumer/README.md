# QuizX ETL Consumer

Consumes submitted question messages from RabbitMQ and writes them to the QuizX MySQL database used by the question app.

Expected queue payload:

```json
{
  "category": "Science",
  "newCategory": "",
  "question": "What is the chemical symbol for gold?",
  "options": ["Au", "Ag", "Fe", "Pb"],
  "answer": "Au"
}
```

`newCategory` can be used instead of `category`.
