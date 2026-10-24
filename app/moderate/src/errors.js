// Error types that preserve safe HTTP status and error-code information.
class AppError extends Error {
  constructor(message, statusCode = 500, code = "INTERNAL_ERROR", details) {
    super(message);
    this.name = this.constructor.name;
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
  }
}

class ConfigurationError extends AppError {
  constructor(message) {
    super(message, 500, "CONFIGURATION_ERROR");
  }
}

class AuthenticationError extends AppError {
  constructor(message = "Authentication is required.") {
    super(message, 401, "UNAUTHENTICATED");
  }
}

class AuthorizationError extends AppError {
  constructor(message = "Moderator access is required.") {
    super(message, 403, "FORBIDDEN");
  }
}

class ValidationError extends AppError {
  constructor(message, details) {
    super(message, 400, "VALIDATION_ERROR", details);
  }
}

class ReviewTokenError extends AppError {
  constructor(message = "The review reservation is invalid or expired.") {
    super(message, 409, "INVALID_REVIEW_TOKEN");
  }
}

module.exports = {
  AppError,
  AuthenticationError,
  AuthorizationError,
  ConfigurationError,
  ReviewTokenError,
  ValidationError,
};
