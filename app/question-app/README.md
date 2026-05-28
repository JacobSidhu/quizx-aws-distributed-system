## QuizX Question App

Version 1.0.0 service for listing quiz categories and returning random questions
without exposing answers.

### Endpoints

- `GET /health` - process health check.
- `GET /ready` - database readiness check.
- `GET /db/health` - compatibility alias for `/ready`.
- `GET /categories` - returns available category names.
- `GET /questions/:category?count=5` - returns random questions for a category.
- `GET /docs` - returns the API summary.

### Local Run

Create `src/.env` with:

```env
PORT=4000
MAX_QUESTION_COUNT=25
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=quizx_app
DB_PASSWORD=quizx_app_password
DB_NAME=quizx
```

Then run:

```bash
cd app/question-app/src
npm install
npm start
```

### Docker Image

Build the image from the repository root:

```bash
docker build -t quizx-question-app:1.0.0 app/question-app
```

The container expects database settings through environment variables and listens
on port `4000`.
