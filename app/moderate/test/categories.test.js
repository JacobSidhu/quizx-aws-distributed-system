// Unit tests for category normalization and upstream failure handling.
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createCategoryClient,
  normalizeCategories,
} = require("../src/categories");

test("normalizes category names", () => {
  assert.deepEqual(
    normalizeCategories([" Science ", "History", "Science", "", null]),
    ["History", "Science"],
  );
});

test("returns normalized categories from the Question App", async () => {
  const client = createCategoryClient(
    { baseUrl: "http://question-app.invalid", timeoutMs: 100 },
    async () => ({
      ok: true,
      json: async () => ({ categories: [" Science ", "History"] }),
    }),
  );

  assert.deepEqual(await client.list(), ["History", "Science"]);
});

test("reports a 503 when the Question App is unavailable", async () => {
  const client = createCategoryClient(
    {
      baseUrl: "http://question-app.invalid",
      timeoutMs: 100,
    },
    async () => {
      throw new Error("unavailable");
    },
  );

  await assert.rejects(client.list(), {
    code: "CATEGORY_SERVICE_UNAVAILABLE",
    statusCode: 503,
  });
});
