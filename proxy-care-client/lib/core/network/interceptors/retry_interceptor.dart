import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../network_config.dart';
import '../request_options.dart';

/// Waits for [delay]; injectable so tests do not sleep.
typedef RetryDelay = Future<void> Function(Duration delay);

/// Retries requests that failed for a transient reason.
///
/// Retried by default: **GET** requests that failed with a connection
/// error or connection timeout, or with HTTP **502, 503 or 504**. Up to
/// [maxRetries] retries, with exponential backoff ([baseDelay], doubling).
///
/// Never retried: cancelled requests, other methods (POST, PUT, PATCH,
/// DELETE are not idempotent by default), and requests whose
/// `RetryPolicy` is disabled. A request with `RetryPolicy(enabled: true)`
/// is retried whatever its method (use it only with an idempotency key).
///
/// The retry loop lives in the first chain that sees the failure. Each
/// retry is dispatched through the whole chain again (so it gets a fresh
/// token and is logged) but is marked as a retry, so no interceptor in the
/// nested chain starts a second loop.
final class RetryInterceptor extends Interceptor {
  /// Creates the interceptor. [dio] dispatches the retries.
  RetryInterceptor({
    required Dio dio,
    this.maxRetries = NetworkConfig.maxRetries,
    this.baseDelay = NetworkConfig.retryBaseDelay,
    RetryDelay? delay,
  }) : _dio = dio,
       _delay = delay ?? Future<void>.delayed;

  final Dio _dio;
  final RetryDelay _delay;

  /// Default number of retries after the first attempt.
  final int maxRetries;

  /// Delay before the first retry.
  final Duration baseDelay;

  static const Set<int> _retryableStatuses = {502, 503, 504};

  /// The delay before retry number [retry] (1-based).
  Duration backoff(int retry) => baseDelay * math.pow(2, retry - 1).toInt();

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    // A retry's failure is returned to the loop that dispatched it.
    if (options.extra[RequestExtra.isRetry] == true) {
      handler.next(err);
      return;
    }

    final policy = options.extra[RequestExtra.retryPolicy] as RetryPolicy?;
    final limit = policy?.maxRetries ?? maxRetries;
    var error = err;
    var retry = 0;
    while (retry < limit && _shouldRetry(error, policy)) {
      retry++;
      await _delay(backoff(retry));
      options.extra[RequestExtra.isRetry] = true;
      options.extra[RequestExtra.retryCount] = retry;
      // A multipart body can be sent once; each retry needs a fresh copy.
      if (options.data case final FormData form) options.data = form.clone();
      try {
        final response = await _dio.fetch<Object?>(options);
        options.extra.remove(RequestExtra.isRetry);
        handler.resolve(response);
        return;
      } on DioException catch (retryError) {
        error = retryError;
      }
    }
    options.extra.remove(RequestExtra.isRetry);
    handler.next(error);
  }

  bool _shouldRetry(DioException error, RetryPolicy? policy) {
    if (error.type == DioExceptionType.cancel) return false;
    if (error.requestOptions.cancelToken?.isCancelled ?? false) return false;
    if (policy != null && !policy.enabled) return false;
    final idempotent = error.requestOptions.method.toUpperCase() == 'GET';
    if (!idempotent && policy == null) return false;

    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout => true,
      DioExceptionType.badResponse => _retryableStatuses.contains(
        error.response?.statusCode,
      ),
      _ => false,
    };
  }
}
