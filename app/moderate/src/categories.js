// Retrieves and normalizes the categories exposed by Question App.
const { AppError } = require("./errors");

function normalizeCategories(categories) {
  if (!Array.isArray(categories)) {
    return [];
  }

  return [
    ...new Set(
      categories
        .filter((category) => typeof category === "string")
        .map((category) => category.trim())
        .filter(Boolean),
    ),
  ].sort((first, second) => first.localeCompare(second));
}

// Calls the Question App with a timeout. An outage is reported as a clear 503
// rather than hidden behind stale data. fetchImplementation is injectable for
// tests.
function createCategoryClient(categoryConfig, fetchImplementation = fetch) {
  function unavailable(message) {
    return new AppError(message, 503, "CATEGORY_SERVICE_UNAVAILABLE");
  }

  return {
    async list() {
      let response;

      try {
        response = await fetchImplementation(
          `${categoryConfig.baseUrl}/categories`,
          { signal: AbortSignal.timeout(categoryConfig.timeoutMs) },
        );
      } catch (error) {
        throw unavailable("The category service is unavailable.");
      }

      const data = await response.json().catch(() => ({}));

      if (!response.ok) {
        throw unavailable(data.message || "Categories could not be loaded.");
      }

      return normalizeCategories(data.categories);
    },
  };
}

module.exports = { createCategoryClient, normalizeCategories };
