// Composes the Moderator Service routes, dependencies, and error responses.
const express = require("express");
const path = require("path");
const { AppError, ValidationError } = require("./errors");
const { validatedQuestion } = require("./question");

const PUBLIC_DIR = path.join(__dirname, "../public");

// Dependencies are injected rather than required directly, so the routes can
// be exercised with a fake queue and authenticator.
function createApp({ config, queue, categoryClient, authenticate }) {
  const app = express();

  // This UI handles privileged actions, so it sends strict security headers.
  app.disable("x-powered-by");
  app.use((req, res, next) => {
    res.set({
      "Content-Security-Policy":
        "default-src 'self'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'",
      "Referrer-Policy": "no-referrer",
      "X-Content-Type-Options": "nosniff",
      "X-Frame-Options": "DENY",
    });
    next();
  });
  app.use(express.json({ limit: "32kb" }));
  app.use("/moderate", (req, res, next) => {
    if (!req.path.startsWith("/assets/")) {
      res.set("Cache-Control", "no-store");
    }
    next();
  });
  app.use("/moderate/assets", express.static(PUBLIC_DIR, { index: false }));

  app.get("/", (req, res) => res.redirect("/moderate"));
  app.get("/moderate", (req, res) => {
    res.sendFile(path.join(PUBLIC_DIR, "index.html"));
  });

  app.get(["/health", "/moderate/health"], (req, res) => {
    res.status(200).json({
      status: "ok",
      app: config.app.name,
      version: config.app.version,
    });
  });

  app.get(["/ready", "/moderate/ready"], async (req, res, next) => {
    try {
      await queue.health();
      res.status(200).json({ status: "ready" });
    } catch (error) {
      next(
        new AppError(
          "The moderation queues are unavailable.",
          503,
          "QUEUE_UNAVAILABLE",
        ),
      );
    }
  });

  // Public, non-sensitive settings the browser needs before signing in. The
  // heartbeat fires 30 seconds before the reservation would expire.
  app.get("/moderate/config", (req, res) => {
    res.status(200).json({
      moderatorGroup: config.auth.moderatorGroup,
      pollIntervalMs: 5000,
      visibilityHeartbeatMs: Math.max(
        10000,
        (config.queues.visibilityTimeoutSeconds - 30) * 1000,
      ),
    });
  });

  app.get(
    ["/categories", "/moderate/categories"],
    authenticate,
    async (req, res, next) => {
      try {
        const categories = await categoryClient.list();
        res.status(200).json({ categories });
      } catch (error) {
        next(error);
      }
    },
  );

  app.get("/moderate/next", authenticate, async (req, res, next) => {
    try {
      const review = await queue.receiveNext();

      if (!review) {
        return res.status(204).end();
      }

      res.status(200).json(review);
    } catch (error) {
      next(error);
    }
  });

  // Validates edits without publishing, so the moderator can fix problems
  // before approving.
  app.put("/moderate/:id", authenticate, async (req, res, next) => {
    try {
      queue.validateReservation(req.params.id, req.body?.reviewToken);
      const question = validatedQuestion(req.body?.question);
      res.status(200).json({ id: req.params.id, question });
    } catch (error) {
      next(error);
    }
  });

  async function approve(req, res, next) {
    try {
      const result = await queue.approve({
        id: req.params.id || req.body?.id,
        token: req.body?.reviewToken,
        input: req.body?.question,
        auth: req.auth,
      });
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  }

  app.post("/moderate/:id/approve", authenticate, approve);
  app.post("/moderate", authenticate, approve);

  app.post("/moderate/:id/reject", authenticate, async (req, res, next) => {
    try {
      const result = await queue.reject({
        id: req.params.id,
        token: req.body?.reviewToken,
        reason: req.body?.reason,
        auth: req.auth,
      });
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  });

  app.post("/moderate/:id/visibility", authenticate, async (req, res, next) => {
    try {
      const result = await queue.extendVisibility({
        id: req.params.id,
        token: req.body?.reviewToken,
      });
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  });

  app.get("/moderate/docs", authenticate, (req, res) => {
    res.status(200).json({
      openapi: "3.0.0",
      info: {
        title: "QuizX Moderator API",
        version: config.app.version,
      },
      endpoints: {
        "GET /moderate/next":
          "Reserves and returns the next submitted question.",
        "PUT /moderate/{id}":
          "Validates an edited question without publishing it.",
        "POST /moderate/{id}/approve":
          "Publishes an approved question and deletes its submission.",
        "POST /moderate/{id}/reject":
          "Deletes a rejected submission without forwarding it.",
        "POST /moderate/{id}/visibility":
          "Extends the current review reservation.",
        "GET /moderate/categories": "Returns existing question categories.",
        "GET /health": "Returns process health.",
        "GET /ready": "Checks both SQS queues.",
      },
    });
  });

  app.use((req, res) => {
    res.status(404).json({
      code: "NOT_FOUND",
      message: "Route not found.",
    });
  });

  // Known application errors return their own status and message. Anything
  // unexpected is logged without request bodies or tokens and returned as 500.
  app.use((error, req, res, next) => {
    if (error.type === "entity.parse.failed") {
      return res.status(400).json({
        code: "INVALID_JSON",
        message: "Request body must contain valid JSON.",
      });
    }

    if (error.type === "entity.too.large") {
      return res.status(413).json({
        code: "PAYLOAD_TOO_LARGE",
        message: "Request body must not exceed 32 KB.",
      });
    }

    const knownError =
      error instanceof AppError || error instanceof ValidationError;

    console.error({
      code: error.code || "INTERNAL_ERROR",
      message: error.message,
      path: req.path,
    });

    res.status(knownError ? error.statusCode : 500).json({
      code: knownError ? error.code : "INTERNAL_ERROR",
      message: knownError ? error.message : "Internal server error.",
      ...(knownError && error.details ? { details: error.details } : {}),
    });
  });

  return app;
}

module.exports = { createApp };
