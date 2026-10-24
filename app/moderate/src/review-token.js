// Protects temporary SQS receipt data in authenticated, expiring review tokens.
const crypto = require("crypto");
const { ConfigurationError, ReviewTokenError } = require("./errors");

// Review tokens let the service stay stateless: the reservation (including
// the SQS receipt handle) travels with the browser, encrypted and signed with
// AES-256-GCM, so any replica can handle the next request. The clock is
// injectable so expiry can be tested deterministically.
function createReviewTokenManager(secret, clock = () => Date.now()) {
  if (typeof secret !== "string" || secret.length < 32) {
    throw new ConfigurationError(
      "REVIEW_TOKEN_SECRET must contain at least 32 characters.",
    );
  }

  const key = crypto.createHash("sha256").update(secret).digest();

  // Token format: base64url(iv).base64url(authTag).base64url(ciphertext)
  function seal(payload, ttlSeconds) {
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
    const data = Buffer.from(
      JSON.stringify({
        ...payload,
        expiresAt: clock() + ttlSeconds * 1000,
      }),
    );
    const encrypted = Buffer.concat([cipher.update(data), cipher.final()]);
    const authenticationTag = cipher.getAuthTag();

    return [iv, authenticationTag, encrypted]
      .map((part) => part.toString("base64url"))
      .join(".");
  }

  // Any failure (malformed, tampered, or expired) maps to the same error so
  // callers cannot tell which check failed.
  function open(token) {
    try {
      const parts = String(token || "").split(".");

      if (parts.length !== 3) {
        throw new Error("Malformed token");
      }

      const [iv, authenticationTag, encrypted] = parts.map((part) =>
        Buffer.from(part, "base64url"),
      );
      const decipher = crypto.createDecipheriv("aes-256-gcm", key, iv);
      decipher.setAuthTag(authenticationTag);
      const plaintext = Buffer.concat([
        decipher.update(encrypted),
        decipher.final(),
      ]);
      const payload = JSON.parse(plaintext.toString("utf8"));

      if (!payload.expiresAt || payload.expiresAt <= clock()) {
        throw new Error("Expired token");
      }

      return payload;
    } catch (error) {
      if (error instanceof ReviewTokenError) {
        throw error;
      }

      throw new ReviewTokenError();
    }
  }

  return { open, seal };
}

module.exports = { createReviewTokenManager };
