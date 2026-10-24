// Normalizes and validates the question contract at the moderation boundary.
const { ValidationError } = require("./errors");

function normalizeText(value) {
  return typeof value === "string" ? value.trim() : "";
}

// Accepts the Submit App payload shape and collapses category, newCategory,
// and finalCategory into the single category field used after moderation.
function normalizeQuestion(input = {}) {
  const source = input && typeof input === "object" ? input : {};
  const options = Array.isArray(source.options)
    ? source.options.map(normalizeText)
    : [];
  const category = normalizeText(
    source.finalCategory || source.newCategory || source.category,
  );

  return {
    question: normalizeText(source.question),
    options,
    answer: normalizeText(source.answer),
    category,
  };
}

function questionValidationErrors(question) {
  const errors = [];

  if (!question.question) {
    errors.push("Question text is required.");
  } else if (question.question.length > 1000) {
    errors.push("Question text must not exceed 1000 characters.");
  }

  if (!question.category) {
    errors.push("Category is required.");
  } else if (question.category.length > 100) {
    errors.push("Category must not exceed 100 characters.");
  }

  if (
    question.options.length !== 4 ||
    question.options.some((option) => !option)
  ) {
    errors.push("Exactly four non-empty answers are required.");
  }

  if (question.options.some((option) => option.length > 500)) {
    errors.push("Answers must not exceed 500 characters.");
  }

  const normalizedOptions = question.options.map((option) =>
    option.toLowerCase(),
  );

  if (new Set(normalizedOptions).size !== question.options.length) {
    errors.push("Answers must be unique.");
  }

  if (!question.answer || !question.options.includes(question.answer)) {
    errors.push(
      "The correct answer must exactly match one of the four answers.",
    );
  }

  return errors;
}

function validatedQuestion(input) {
  const question = normalizeQuestion(input);
  const errors = questionValidationErrors(question);

  if (errors.length > 0) {
    throw new ValidationError("The moderated question is invalid.", errors);
  }

  return question;
}

module.exports = {
  normalizeQuestion,
  questionValidationErrors,
  validatedQuestion,
};
