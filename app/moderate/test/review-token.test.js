// Unit tests for encrypted review-token creation and verification.
const test = require("node:test");
const assert = require("node:assert/strict");
const { createReviewTokenManager } = require("../src/review-token");

const SECRET = "local-test-secret-that-is-long-enough";

test("seals and opens an opaque review reservation", () => {
  const manager = createReviewTokenManager(SECRET, () => 1000);
  const token = manager.seal(
    {
      id: "submission-1",
      receiptHandle: "receipt-1",
    },
    60,
  );

  assert.equal(token.includes("receipt-1"), false);
  assert.deepEqual(manager.open(token), {
    id: "submission-1",
    receiptHandle: "receipt-1",
    expiresAt: 61000,
  });
});

test("rejects expired and tampered review tokens", () => {
  let now = 1000;
  const manager = createReviewTokenManager(SECRET, () => now);
  const token = manager.seal({ id: "submission-1" }, 1);
  const parts = token.split(".");
  parts[2] = `${parts[2][0] === "A" ? "B" : "A"}${parts[2].slice(1)}`;
  const tamperedToken = parts.join(".");

  now = 2001;
  assert.throws(() => manager.open(token), { code: "INVALID_REVIEW_TOKEN" });
  assert.throws(() => manager.open(tamperedToken), {
    code: "INVALID_REVIEW_TOKEN",
  });
});
