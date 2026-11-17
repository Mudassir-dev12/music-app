/// Dio-based HTTP client with auth-token injection and 401 single-flight refresh.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart' as config;
import '../core/connectivity/connectivity_controller.dart';
import 'errors.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Global provider for the [ApiClient].
///
/// The [SessionController] must call [ApiClient.setAccessToken] after sign-in
/// and [ApiClient.clearAccessToken] after sign-out.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  client.onNetworkFailure = (err) {
    ref.read(connectivityProvider.notifier).reportFailure(error: err);
  };
  return client;
});

// ---------------------------------------------------------------------------
// ApiClient
// ---------------------------------------------------------------------------

/// Low-level HTTP client wrapping Dio.
///
/// Features:
/// - Injects `Authorization: Bearer <token>` via interceptor.
/// - On 401: single-flight token refresh; concurrent 401s all wait for the
///   same refresh attempt, then retry once.
/// - Parses backend error bodies into typed [ApiError] subclasses.
class ApiClient {
  ApiClient({Dio? dio}) {
    _dio = dio ??
        Dio(BaseOptions(
          baseUrl: config.apiUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          // We validate status ourselves so we can catch 4xx/5xx in the interceptor.
          validateStatus: (_) => true,
        ));

    if (dio == null) {
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ));
    }
  }

  late final Dio _dio;

  String? _accessToken;

  // Single-flight state for refresh.
  Completer<String?>? _refreshCompleter;

  // Callback set by SessionController so the interceptor can trigger refresh.
  Future<String?> Function(String path)? onRefreshNeeded;

  // Callback set by SessionController so the interceptor can clear session on
  // permanent 401 (refresh failed).
  void Function()? onSessionExpired;

  // Callback set by provider to notify connectivity state of network failures.
  void Function(Object error)? onNetworkFailure;

  /// Updates the base URL for Dio and global config.
  void updateBaseUrl(String newUrl) {
    config.setApiUrl(newUrl);
    _dio.options.baseUrl = newUrl;
  }

  /// Loads custom base URL persisted in SharedPreferences, if present.
  Future<void> loadCustomBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customUrl = prefs.getString('custom_api_url');
      if (customUrl != null && customUrl.isNotEmpty) {
        if (customUrl.contains('192.168.') || customUrl.contains('10.0.2.2') || customUrl.contains('127.0.0.1')) {
          await prefs.remove('custom_api_url');
        } else {
          updateBaseUrl(customUrl);
        }
      }
    } catch (_) {}
  }

  /// Updates the in-memory access token used for future requests.
  void setAccessToken(String token) => _accessToken = token;

  /// Clears the in-memory access token.
  void clearAccessToken() => _accessToken = null;

  // ---------------------------------------------------------------------------
  // Interceptor callbacks
  // ---------------------------------------------------------------------------

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_accessToken != null) {
      options.headers['Authorization'] = 'Bearer $_accessToken';
    }
    handler.next(options);
  }

  Future<void> _onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    if (response.statusCode == 401) {
      // Attempt a single-flight refresh.
      final newToken = await _doSingleFlightRefresh(response.requestOptions.path);
      if (newToken != null) {
        // Retry the original request with the new token.
        response.requestOptions.headers['Authorization'] = 'Bearer $newToken';
        try {
          final retried = await _dio.fetch<dynamic>(response.requestOptions);
          handler.resolve(retried);
        } on DioException catch (e) {
          handler.reject(e);
        }
        return;
      } else {
        onSessionExpired?.call();
      }
    }
    final err = _errorFromResponse(response);
    if (err != null) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: err,
        ),
      );
      return;
    }
    handler.next(response);
  }

  void _onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.error is ApiError) {
      handler.reject(err);
      return;
    }
    final apiErr = _errorFromDioException(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        error: apiErr,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Single-flight refresh
  // ---------------------------------------------------------------------------

  Future<String?> _doSingleFlightRefresh(String path) async {
    if (_refreshCompleter != null) {
      // Another refresh is already in flight — wait for its result.
      return _refreshCompleter!.future;
    }
    _refreshCompleter = Completer<String?>();
    try {
      final newToken = await onRefreshNeeded?.call(path);
      _refreshCompleter!.complete(newToken);
      return newToken;
    } catch (_) {
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Error parsing
  // ---------------------------------------------------------------------------

  /// Returns an [ApiError] if [response] indicates a failure, or null if OK.
  ApiError? _errorFromResponse(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) return null;

    final body = response.data;

    switch (status) {
      case 401:
        return const UnauthorizedError();
      case 403:
        return ForbiddenError(_detail(body));
      case 404:
        return UnknownError(_detail(body, 'Resource not found.'));
      case 409:
        return ConflictError(_detail(body));
      case 422:
        return _parseValidationError(body);
      case 429:
        final retryAfter = _parseRetryAfter(response);
        return RateLimitError(retryAfterSeconds: retryAfter);
      case 502:
      case 503:
        final retryAfter = _parseRetryAfter(response);
        return UpstreamBusyError(
          retryAfterSeconds: retryAfter > 0 ? retryAfter : 5,
          message: _detail(body, 'The music service is busy right now.'),
        );
      default:
        if (status >= 500) {
          return ServerError(
            statusCode: status,
            message: _detail(body, 'Server error ($status).'),
          );
        }
        return UnknownError(_detail(body));
    }
  }

  ApiError _errorFromDioException(DioException e) {
    if (e.error is ApiError) return e.error as ApiError;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const NetworkError('Request timed out.');
      case DioExceptionType.connectionError:
        return const NetworkError();
      default:
        return UnknownError(e.message ?? 'Unknown error.');
    }
  }

  String _detail(dynamic body, [String fallback = 'An error occurred.']) {
    if (body is Map<String, dynamic>) {
      final d = body['detail'];
      if (d is String) return d;
    }
    return fallback;
  }

  ValidationError _parseValidationError(dynamic body) {
    final fields = <String, String>{};
    if (body is Map<String, dynamic>) {
      final detail = body['detail'];
      if (detail is List) {
        for (final item in detail) {
          if (item is Map<String, dynamic>) {
            final loc = (item['loc'] as List?)?.join('.') ?? 'field';
            final msg = item['msg'] as String? ?? 'Invalid value';
            fields[loc] = msg;
          }
        }
      } else if (detail is String) {
        return ValidationError(fields: const {}, message: detail);
      }
    }
    return ValidationError(fields: fields);
  }

  int _parseRetryAfter(Response<dynamic> response) {
    final header = response.headers.value('retry-after');
    if (header != null) {
      return int.tryParse(header) ?? 60;
    }
    return 60;
  }

  // ---------------------------------------------------------------------------
  // Public HTTP methods
  // ---------------------------------------------------------------------------

  /// Retries idempotent requests (GET/HEAD) up to 2 times with backoff.
  Future<dynamic> _retryIdempotent(Future<dynamic> Function() request) async {
    const maxRetries = 2;
    const delays = [Duration(milliseconds: 500), Duration(milliseconds: 1500)];

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await request();
      } on ApiError catch (e) {
        final shouldRetry = (e is NetworkError ||
            e is UpstreamBusyError ||
            (e is ServerError &&
                (e.statusCode == 502 || e.statusCode == 503 || e.statusCode == 504)));
        if (!shouldRetry || attempt == maxRetries) {
          onNetworkFailure?.call(e);
          rethrow;
        }

        Duration delay = delays[attempt];
        if (e is UpstreamBusyError && e.retryAfterSeconds > 0 && e.retryAfterSeconds <= 5) {
          delay = Duration(seconds: e.retryAfterSeconds);
        } else if (e is RateLimitError && e.retryAfterSeconds > 0 && e.retryAfterSeconds <= 5) {
          delay = Duration(seconds: e.retryAfterSeconds);
        }
        await Future<void>.delayed(delay);
      } catch (e) {
        if (attempt == maxRetries) {
          onNetworkFailure?.call(e);
          rethrow;
        }
        await Future<void>.delayed(delays[attempt]);
      }
    }
  }

  @visibleForTesting
  Future<dynamic> retryIdempotentForTesting(Future<dynamic> Function() request) =>
      _retryIdempotent(request);

  /// GET [path] with optional [queryParams]. Returns decoded JSON.
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    return _retryIdempotent(() async {
      try {
        final resp = await _dio.get<dynamic>(path, queryParameters: queryParams);
        return resp.data;
      } on DioException catch (e) {
        throw e.error is ApiError ? e.error as ApiError : UnknownError(e.message ?? '');
      }
    });
  }

  /// POST [path] with a JSON [body]. Returns decoded JSON. Never auto-retried.
  Future<dynamic> post(String path, dynamic body) async {
    try {
      final resp = await _dio.post<dynamic>(path, data: body);
      return resp.data;
    } on DioException catch (e) {
      final err = e.error is ApiError ? e.error as ApiError : UnknownError(e.message ?? '');
      onNetworkFailure?.call(err);
      throw err;
    }
  }

  /// PUT [path] with optional [body]. Returns decoded JSON. Never auto-retried.
  Future<dynamic> put(String path, [dynamic body]) async {
    try {
      final resp = await _dio.put<dynamic>(path, data: body);
      return resp.data;
    } on DioException catch (e) {
      final err = e.error is ApiError ? e.error as ApiError : UnknownError(e.message ?? '');
      onNetworkFailure?.call(err);
      throw err;
    }
  }

  /// PATCH [path] with a JSON [body]. Returns decoded JSON. Never auto-retried.
  Future<dynamic> patch(String path, dynamic body) async {
    try {
      final resp = await _dio.patch<dynamic>(path, data: body);
      return resp.data;
    } on DioException catch (e) {
      final err = e.error is ApiError ? e.error as ApiError : UnknownError(e.message ?? '');
      onNetworkFailure?.call(err);
      throw err;
    }
  }

  /// DELETE [path] with optional [queryParams]. Returns decoded JSON. Never auto-retried.
  Future<dynamic> delete(String path, {Map<String, dynamic>? queryParams}) async {
    try {
      final resp = await _dio.delete<dynamic>(path, queryParameters: queryParams);
      return resp.data;
    } on DioException catch (e) {
      final err = e.error is ApiError ? e.error as ApiError : UnknownError(e.message ?? '');
      onNetworkFailure?.call(err);
      throw err;
    }
  }

  /// HEAD [path] for warmup/pre-resolving streams.
  Future<dynamic> head(String path) async {
    return _retryIdempotent(() async {
      try {
        final resp = await _dio.head<dynamic>(path);
        return resp.data;
      } on DioException catch (e) {
        throw e.error is ApiError ? e.error as ApiError : UnknownError(e.message ?? '');
      }
    });
  }

  /// POST [path] with form-encoded body (no data). Returns decoded JSON. Never auto-retried.
  Future<dynamic> postForm(String path) async {
    try {
      final resp = await _dio.post<dynamic>(
        path,
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );
      return resp.data;
    } on DioException catch (e) {
      final err = e.error is ApiError ? e.error as ApiError : UnknownError(e.message ?? '');
      onNetworkFailure?.call(err);
      throw err;
    }
  }
}
