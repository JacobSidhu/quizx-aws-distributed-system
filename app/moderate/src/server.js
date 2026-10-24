// Process entry point for validating configuration and starting the HTTP server.
const { createApp } = require("./app");
const { createAuthenticator } = require("./auth");
const { createCategoryClient } = require("./categories");
const { config, validateRuntimeConfig } = require("./config");
const {
  ModerationQueue,
  createQueueClient,
  resolveQueueUrls,
} = require("./queue");
const { createReviewTokenManager } = require("./review-token");

let server;
let sqsClient;

// Validates configuration and resolves both SQS queues before listening, so a
// misconfigured deployment fails at startup instead of on the first request.
async function start() {
  validateRuntimeConfig(config);

  sqsClient = createQueueClient(config.aws);
  const queueConfig = await resolveQueueUrls(sqsClient, config.queues);
  const tokenManager = createReviewTokenManager(config.reviewTokenSecret);
  const queue = new ModerationQueue({
    client: sqsClient,
    queueConfig,
    tokenManager,
  });
  const app = createApp({
    config,
    queue,
    categoryClient: createCategoryClient(config.categories),
    authenticate: createAuthenticator(config.auth),
  });

  server = app.listen(config.app.port, () => {
    console.log(`${config.app.name} running on port ${config.app.port}`);
  });
}

async function shutdown(signal) {
  console.log(`Received ${signal}; shutting down.`);

  if (!server) {
    sqsClient?.destroy();
    process.exit(0);
  }

  server.close(async () => {
    sqsClient?.destroy();
    process.exit(0);
  });
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));

start().catch((error) => {
  console.error(`Failed to start ${config.app.name}: ${error.message}`);
  sqsClient?.destroy();
  process.exitCode = 1;
});
