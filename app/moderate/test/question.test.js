// Unit tests for the moderated-question validation contract.
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizeQuestion,
  questionValidationErrors,
  validatedQuestion,
} = require("../src/question");

test("normalizes the Submit Service payload and final category", () => {
  assert.deepEqual(
    normalizeQuestion({
      question: "  Capital of France? ",
      options: [" Paris ", "Rome", "Berlin", "Madrid"],
      answer: " Paris ",
      category: "Geography",
      finalCategory: " European Geography ",
    }),
    {
      question: "Capital of France?",
      options: ["Paris", "Rome", "Berlin", "Madrid"],
      answer: "Paris",
      category: "European Geography",
    },
  );
});

test("requires four unique answers and one exact correct answer", () => {
  const errors = questionValidationErrors(
    normalizeQuestion({
      question: "Question",
      options: ["A", "a", "C", ""],
      answer: "B",
      category: "Category",
    }),
  );

  assert.deepEqual(errors, [
    "Exactly four non-empty answers are required.",
    "Answers must be unique.",
    "The correct answer must exactly match one of the four answers.",
  ]);
});

test("validatedQuestion rejects invalid input with details", () => {
  assert.throws(
    () => validatedQuestion({}),
    (error) => error.code === "VALIDATION_ERROR" && error.details.length > 0,
  );
});
