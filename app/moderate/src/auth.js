// Builds the Amazon Cognito request authenticator for moderation routes.
const { CognitoJwtVerifier } = require("aws-jwt-verify");
const {
  AuthenticationError,
  AuthorizationError,
  ConfigurationError,
} = require("./errors");

// Returns Express middleware that sets req.auth for an authorised moderator.
// The bearer token must be a valid Cognito access token for the configured app
// client and must include the moderator group. There is no bypass mode.
function createAuthenticator(authConfig) {
  if (!authConfig.userPoolId || !authConfig.clientId) {
    throw new ConfigurationError(
      "Cognito authentication requires COGNITO_USER_POOL_ID and COGNITO_CLIENT_ID.",
    );
  }

  const verifier = CognitoJwtVerifier.create({
    userPoolId: authConfig.userPoolId,
    tokenUse: "access",
    clientId: authConfig.clientId,
  });

  return async (req, res, next) => {
    try {
      const authorization = req.get("authorization") || "";
      const match = authorization.match(/^Bearer\s+(.+)$/i);

      if (!match) {
        throw new AuthenticationError();
      }

      let payload;

      try {
        payload = await verifier.verify(match[1]);
      } catch (error) {
        throw new AuthenticationError(
          "The access token is invalid or expired.",
        );
      }

      const groups = Array.isArray(payload["cognito:groups"])
        ? payload["cognito:groups"]
        : [];

      if (
        authConfig.moderatorGroup &&
        !groups.includes(authConfig.moderatorGroup)
      ) {
        throw new AuthorizationError();
      }

      req.auth = {
        subject: payload.sub,
        username: payload.username || payload.sub,
        groups,
      };
      next();
    } catch (error) {
      next(error);
    }
  };
}

module.exports = { createAuthenticator };
