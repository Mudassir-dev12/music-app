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
  const NetworkError([super.message = "Can't reach the music server. Check your connection; we'll keep trying."]);
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
      : super('Too many requests. Try again in $retryAfterSeconds seconds.');

  final int retryAfterSeconds;
}

/// HTTP 502 / 503 — upstream music service busy; [retryAfterSeconds] from the Retry-After header.
class UpstreamBusyError extends ApiError {
  const UpstreamBusyError({
    this.retryAfterSeconds = 5,
    String message = 'The music server is starting or busy. Try again in a moment.',
  }) : super(message);

  final int retryAfterSeconds;
}

/// HTTP 5xx — server-side error.
class ServerError extends ApiError {
  const ServerError({required this.statusCode, String message = 'The music server is starting or busy. Try again in a moment.'})
      : super(message);

  final int statusCode;
}

/// Any other unexpected error.
class UnknownError extends ApiError {
  const UnknownError([super.message = 'Something went wrong. Try again.']);
}

/// Returns a user-friendly message for any error.
String userFacingErrorMessage(Object error) {
  if (error is NetworkError) {
    return "Can't reach the music server. Check your connection; we'll keep trying.";
  }
  if (error is UpstreamBusyError) {
    return "The music server is starting or busy. Try again in a moment.";
  }
  if (error is ServerError) {
    if (error.statusCode == 502 || error.statusCode == 503 || error.statusCode == 504) {
      return "The music server is starting or busy. Try again in a moment.";
    }
    return "The music server is starting or busy. Try again in a moment.";
  }
  if (error is RateLimitError) {
    return "Too many requests. Try again in ${error.retryAfterSeconds} seconds.";
  }
  if (error is UnauthorizedError) {
    return "Sign in required. Please check your credentials.";
  }
  if (error is ConflictError) {
    return error.message;
  }
  if (error is ValidationError) {
    return error.message;
  }
  final errStr = error.toString().toLowerCase();
  if (errStr.contains('connection') || errStr.contains('socket') || errStr.contains('timeout')) {
    return "Can't reach the music server. Check your connection; we'll keep trying.";
  }
  return "Something went wrong. Try again.";
}

/// Returns true if [error] represents a transient network or server unavailability.
bool isNetworkError(Object error) {
  if (error is NetworkError || error is UpstreamBusyError) return true;
  if (error is ServerError &&
      (error.statusCode == 502 || error.statusCode == 503 || error.statusCode == 504)) {
    return true;
  }
  final errStr = error.toString().toLowerCase();
  return errStr.contains('socket') ||
      errStr.contains('connection') ||
      errStr.contains('timeout') ||
      errStr.contains('unreachable');
}
