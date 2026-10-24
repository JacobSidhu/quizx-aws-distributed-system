// HTTP entry point for the Submit App. Validates proposed questions and
// publishes them to the submitted-questions SQS queue for moderator review.
// This service has no database access, so nothing reaches RDS unmoderated.
const express = require("express");
const fs = require("fs/promises");
const os = require("os");
const path = require("path");
const config = require("./config");
const queue = require("./queue");

const app = express();
const PUBLIC_DIR = path.join(__dirname, "../public");

app.use(express.json());

// Assets are also served under /submit/assets so the UI works behind a load
// balancer that routes on the /submit path prefix.
app.use("/submit/assets", express.static(PUBLIC_DIR, { index: false }));
app.use(express.static(PUBLIC_DIR, { index: false }));

app.get("/", (req, res) => {
  res.sendFile(path.join(PUBLIC_DIR, "index.html"));
});

app.get("/submit", (req, res) => {
  res.sendFile(path.join(PUBLIC_DIR, "index.html"));
});

// Liveness probe: confirms the process is up without calling AWS.
app.get(["/health", "/submit/health"], (req, res) => {
  res.status(200).json({
    status: "ok",
    app: config.app.name,
    version: config.app.version,
  });
});

// Readiness probe: the service only reports ready once SQS is reachable.
app.get(["/ready", "/submit/ready"], checkQueueReadiness);
app.get(["/queue/health", "/submit/queue/health"], checkQueueReadiness);

app.get(["/categories", "/submit/categories"], async (req, res, next) => {
  try {
    const result = await getCategoriesWithCache();

    res.status(200).json({
      categories: result.categories,
      source: result.source,
    });
  } catch (error) {
    next(error);
  }
});

app.get(["/docs", "/submit/docs"], (req, res) => {
  res.status(200).json({
    openapi: "3.0.0",
    info: {
      title: "QuizX Submit App API",
      version: config.app.version,
    },
    endpoints: {
      "GET /health": "Returns process health.",
      "GET /ready": "Checks moderation queue connectivity.",
      "GET /categories":
        "Returns categories from the question app, or the local cache if the question app is unavailable.",
      "POST /submit": "Publishes a question for moderator review.",
      "GET /docs": "Returns this API documentation.",
    },
    submitPayload: {
      category:
        "string (existing category; leave empty when newCategory is set)",
      newCategory: "string (new category; leave empty when category is set)",
      question: "string",
      options: "string[4] (unique, non-empty)",
      answer: "string (must match one of options)",
    },
  });
});

async function checkQueueReadiness(req, res, next) {
  try {
    await queue.checkReadiness();

    res.status(200).json({
      status: "ok",
      queue: "sqs",
    });
  } catch (error) {
    next(error);
  }
}

// Accepts one question, validates it, and queues it for moderation. Responds
// with 202 because the question is not published until a moderator approves it.
app.post("/submit", async (req, res, next) => {
  try {
    const submission = normalizeSubmission(req.body);
    const validationError = validateSubmission(submission);

    if (validationError) {
      return res.status(400).json({ message: validationError });
    }

    const finalCategory = submission.newCategory || submission.category;
    const queuePayload = {
      ...submission,
      finalCategory,
    };
    const questionRecord = {
      question: submission.question,
      options: submission.options,
      answer: submission.answer,
    };

    await queue.publishSubmission(queuePayload);

    console.log("Submitted question published for moderation:", {
      category: finalCategory,
    });

    res.status(202).json({
      message: "Question submitted to queue successfully",
      category: finalCategory,
      question: questionRecord,
    });
  } catch (error) {
    next(error);
  }
});

// Fetches categories from the Question App and caches the last good response
// on disk. If the Question App is unavailable, the cached list is served so
// users can still submit questions.
async function getCategoriesWithCache() {
  try {
    const response = await fetch(`${config.questionApp.baseUrl}/categories`);
    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.message || "Categories could not be loaded.");
    }

    const categories = normalizeCategories(data.categories);

    await writeCategoryCache(categories);

    return {
      categories,
      source: "question-app",
    };
  } catch (error) {
    const categories = await readCategoryCache();

    if (categories.length > 0) {
      return {
        categories,
        source: "cache",
      };
    }

    error.statusCode = 503;
    throw error;
  }
}

// Trims, de-duplicates, and sorts category names.
function normalizeCategories(categories) {
  if (!Array.isArray(categories)) {
    return [];
  }

  return [...new Set(categories.map(normalizeText).filter(Boolean))].sort(
    (first, second) => first.localeCompare(second),
  );
}

async function writeCategoryCache(categories) {
  await fs.mkdir(path.dirname(config.categoryCache.file), {
    recursive: true,
  });

  await fs.writeFile(
    config.categoryCache.file,
    `${JSON.stringify({ categories }, null, 2)}${os.EOL}`,
    "utf8",
  );
}

// A missing cache file is expected on first start and is treated as empty.
async function readCategoryCache() {
  try {
    const cache = await fs.readFile(config.categoryCache.file, "utf8");
    const data = JSON.parse(cache);

    return normalizeCategories(data.categories);
  } catch (error) {
    if (error.code === "ENOENT") {
      return [];
    }

    throw error;
  }
}

app.use((req, res) => {
  res.status(404).json({
    message: "Route not found",
  });
});

// Errors tagged with a statusCode are safe to return to the client; anything
// else is logged and reported as a generic 500.
app.use((error, req, res, next) => {
  console.error(error);

  res.status(error.statusCode || 500).json({
    message: error.statusCode ? error.message : "Internal server error",
  });
});

// Stops accepting connections, lets in-flight requests finish, then releases
// the SQS client so the container exits cleanly on SIGTERM.
async function shutdown(server) {
  server.close(async () => {
    try {
      await queue.close();
      process.exit(0);
    } catch (error) {
      console.error(error);
      process.exit(1);
    }
  });
}

function normalizeText(value) {
  return typeof value === "string" ? value.trim() : "";
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
    answer: normalizeText(body.answer),
  };
}

// Returns the first validation message, or an empty string when the
// submission is valid. The ETL Consumer applies the same rules again before
// writing to RDS.
function validateSubmission(submission) {
  const categoryCount = [submission.category, submission.newCategory].filter(
    Boolean,
  ).length;

  if (!submission.question) {
    return "Question is required.";
  }

  if (categoryCount !== 1) {
    return "Choose an existing category or add one new category.";
  }

  if (
    submission.options.length !== 4 ||
    submission.options.some((option) => !option)
  ) {
    return "Exactly four answer options are required.";
  }

  const uniqueOptions = new Set(
    submission.options.map((option) => option.toLowerCase()),
  );

  if (uniqueOptions.size !== 4) {
    return "Answer options must be unique.";
  }

  if (!submission.answer || !submission.options.includes(submission.answer)) {
    return "Select one correct answer from the four options.";
  }

  return "";
}

const server = app.listen(config.app.port, () => {
  console.log(`${config.app.name} running on port ${config.app.port}`);
});

process.on("SIGINT", () => shutdown(server));
process.on("SIGTERM", () => shutdown(server));
