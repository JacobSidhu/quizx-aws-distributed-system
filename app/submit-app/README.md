## QuizX Submit App

Version 1.0.0 service for adding quiz categories and questions to MySQL.

### Endpoints

- `GET /health` - process health check.
- `GET /ready` - database readiness check.
- `GET /db/health` - compatibility alias for `/ready`.
- `GET /categories` - returns available category names.
- `POST /submit` - validates and stores one submitted question.
- `GET /docs` - returns the API summary.

### Submit Payload

```json
{
  "category": "Science",
  "newCategory": "",
  "question": "What is the chemical symbol for gold?",
  "options": ["Au", "Ag", "Fe", "Pb"],
  "answer": "Au"
}
```

Provide exactly one of `category` or `newCategory`. The request must include
exactly four unique options, and `answer` must match one option.

### Local Run

Create `src/.env` with:

```env
PORT=4200
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=quizx_app
DB_PASSWORD=quizx_app_password
DB_NAME=quizx
```

Then run:

```bash
cd app/submit-app/src
npm install
npm start
```

### Docker Image

Build the image from the repository root:

```bash
docker build -t quizx-submit-app:1.0.0 app/submit-app
```

The container expects database settings through environment variables and listens
on port `4200`.
