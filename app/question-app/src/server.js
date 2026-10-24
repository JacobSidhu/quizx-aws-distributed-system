// HTTP entry point for the Question App. Serves the quiz UI and a read-only API
// backed by Amazon RDS for MySQL. This service never writes to the database.
const express = require("express");
const path = require("path");
const config = require("./config");
const database = require("./db");

const app = express();
const PUBLIC_DIR = path.join(__dirname, "../public");

app.use(express.json());

// Assets are also served under /question/assets so the UI works behind a
// load balancer that routes on the /question path prefix.
app.use("/question/assets", express.static(PUBLIC_DIR, { index: false }));
app.use(express.static(PUBLIC_DIR, { index: false }));

app.get("/", (req, res) => {
  res.redirect(302, "/question");
});

app.get("/question", (req, res) => {
  res.sendFile(path.join(PUBLIC_DIR, "index.html"));
});

// Liveness probe: confirms the process is up without touching the database.
app.get(["/health", "/question/health"], (req, res) => {
  res.status(200).json({
    status: "ok",
    app: config.app.name,
    version: config.app.version,
  });
});

// Readiness probe: the service only reports ready once RDS is reachable.
app.get(["/ready", "/question/ready"], checkDatabaseReadiness);
app.get(["/db/health", "/question/db/health"], checkDatabaseReadiness);

async function checkDatabaseReadiness(req, res, next) {
  try {
    await database.query("SELECT 1");

    res.status(200).json({
      status: "ok",
      database: config.db.name,
    });
  } catch (error) {
    next(error);
  }
}

app.get(["/docs", "/question/docs"], (req, res) => {
  res.status(200).json({
    openapi: "3.0.0",
    info: {
      title: "QuizX Question App API",
      version: config.app.version,
    },
    endpoints: {
      "GET /health": "Returns process health.",
      "GET /ready": "Checks database connectivity.",
      "GET /categories": "Returns all available quiz categories.",
      "GET /question/:category?count=5":
        "Returns random questions with randomized answer options.",
      "GET /questions/:category?count=5":
        "Compatibility alias for GET /question/:category.",
    },
    limits: {
      maxQuestionCount: config.app.maxQuestionCount,
    },
  });
});

app.get(["/categories", "/question/categories"], async (req, res, next) => {
  try {
    res.status(200).json({
      categories: await getCategoryNames(),
    });
  } catch (error) {
    next(error);
  }
});

// Returns up to `count` random questions for one category. Options are
// shuffled on every request so the correct answer does not sit in a fixed slot.
app.get(
  ["/question/:category", "/questions/:category"],
  async (req, res, next) => {
    try {
      const requestedCategory = normalizeText(
        req.params.category,
      ).toLowerCase();

      if (!requestedCategory) {
        return res.status(400).json({
          message: "Category is required",
        });
      }

      const [categories] = await database.query(
        "SELECT id, name FROM categories WHERE LOWER(name) = LOWER(?) LIMIT 1",
        [requestedCategory],
      );
      const selectedCategory = categories[0];

      if (!selectedCategory) {
        return res.status(404).json({
          message: "Category not found",
          availableCategories: await getCategoryNames(),
        });
      }

      const count = normalizeQuestionCount(req.query.count);

      const [questions] = await database.query(
        `
        SELECT id, question_text, answer
        FROM questions
        WHERE category_id = ?
        ORDER BY RAND()
        LIMIT ?
      `,
        [selectedCategory.id, count],
      );

      if (questions.length === 0) {
        return res.status(404).json({
          message: "No questions found for this category",
        });
      }

      // Load the options for every selected question in a single query.
      const questionIds = questions.map((question) => question.id);
      const optionPlaceholders = questionIds.map(() => "?").join(", ");
      const [options] = await database.query(
        `
        SELECT question_id, option_text, is_correct
        FROM question_options
        WHERE question_id IN (${optionPlaceholders})
        ORDER BY id
      `,
        questionIds,
      );
      const optionsByQuestionId = options.reduce((result, option) => {
        result[option.question_id] = result[option.question_id] || [];
        result[option.question_id].push({
          text: option.option_text,
          isCorrect: Boolean(option.is_correct),
        });

        return result;
      }, {});

      const safeQuestions = questions.map((question) => {
        const options = shuffle(optionsByQuestionId[question.id] || []);
        const correctOption = options.find((option) => option.isCorrect);

        return {
          question: question.question_text,
          answer: correctOption?.text || question.answer,
          options: options.map((option) => option.text),
        };
      });

      res.status(200).json({
        category: selectedCategory.name,
        requestedCount: count,
        returnedCount: safeQuestions.length,
        questions: safeQuestions,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.use((req, res) => {
  res.status(404).json({
    message: "Route not found",
  });
});

// Log the full error server-side but never expose internals to the client.
app.use((error, req, res, next) => {
  console.error(error);

  res.status(500).json({
    message: "Internal server error",
  });
});

async function getCategoryNames() {
  const [categories] = await database.query(
    "SELECT name FROM categories ORDER BY name",
  );

  return categories.map((item) => item.name);
}

// Clamps the requested count to the range 1..MAX_QUESTION_COUNT.
function normalizeQuestionCount(value) {
  const count = parseInt(value, 10);

  if (!count || count < 1) {
    return 1;
  }

  return Math.min(count, config.app.maxQuestionCount);
}

function normalizeText(value) {
  return typeof value === "string" ? value.trim() : "";
}

// Fisher-Yates shuffle. Returns a new array and leaves the input untouched.
function shuffle(values) {
  const shuffled = [...values];

  for (let index = shuffled.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(Math.random() * (index + 1));
    [shuffled[index], shuffled[swapIndex]] = [
      shuffled[swapIndex],
      shuffled[index],
    ];
  }

  return shuffled;
}

// Stops accepting connections, lets in-flight requests finish, then closes the
// connection pool so the container exits cleanly on SIGTERM.
async function shutdown(server) {
  server.close(async () => {
    try {
      await database.end();
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

process.on("SIGINT", () => shutdown(server));
process.on("SIGTERM", () => shutdown(server));
