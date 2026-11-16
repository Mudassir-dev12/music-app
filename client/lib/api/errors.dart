/// Typed API error hierarchy for Melodia.
library;

/// Base class for all API errors.
abstract class ApiError implements Exception {
  const ApiError(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// A network-level failure (no connectivity, timeout, etc.).
class NetworkError extends ApiError {
  const NetworkError([super.message = 'Network error. Check your connection.']);
}

/// HTTP 401 — credentials invalid or access token expired and refresh failed.
class UnauthorizedError extends ApiError {
  const UnauthorizedError([super.message = 'Unauthorized. Please sign in again.']);
}

/// HTTP 403 — authenticated but not permitted to perform this action.
class ForbiddenError extends ApiError {
  const ForbiddenError([super.message = 'You do not have permission to perform this action.']);
}

/// HTTP 409 — resource already exists (e.g. email already registered).
class ConflictError extends ApiError {
  const ConflictError([super.message = 'A conflict occurred. The resource may already exist.']);
}

/// HTTP 422 — validation error; [fields] maps field paths to human-readable messages.
class ValidationError extends ApiError {
  const ValidationError({required this.fields, String message = 'Validation failed.'})
      : super(message);

  final Map<String, String> fields;
}

/// HTTP 429 — rate limited; [retryAfterSeconds] from the Retry-After header.
class RateLimitError extends ApiError {
  const RateLimitError({required this.retryAfterSeconds})
      : super('Too many requests. Please try again later.');

  final int retryAfterSeconds;
}

/// HTTP 502 / 503 — upstream music service busy; [retryAfterSeconds] from the Retry-After header.
class UpstreamBusyError extends ApiError {
  const UpstreamBusyError({
    this.retryAfterSeconds = 5,
    String message = 'The music service is busy right now. Retrying shortly...',
  }) : super(message);

  final int retryAfterSeconds;
}

/// HTTP 5xx — server-side error.
class ServerError extends ApiError {
  const ServerError({required this.statusCode, String message = 'An unexpected server error occurred.'})
      : super(message);

  final int statusCode;
}

/// Any other unexpected error.
class UnknownError extends ApiError {
  const UnknownError([super.message = 'An unknown error occurred.']);
}
