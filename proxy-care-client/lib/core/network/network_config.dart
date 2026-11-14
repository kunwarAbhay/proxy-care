/// Fixed networking settings shared by every request.
abstract final class NetworkConfig {
  /// Time allowed to open a connection.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Time allowed between response bytes.
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Time allowed to send the request body. Applied only to requests that
  /// have a body: on web, Dio warns when a send timeout is set on a request
  /// without one.
  static const Duration sendTimeout = Duration(seconds: 30);

  /// Retries after the first attempt (see `RetryInterceptor`).
  static const int maxRetries = 3;

  /// Delay before the first retry; doubled for each further retry
  /// (0.5 s, 1 s, 2 s).
  static const Duration retryBaseDelay = Duration(milliseconds: 500);
}

/// HTTP header names used by the client.
abstract final class ApiHeaders {
  /// Bearer token.
  static const String authorization = 'Authorization';

  /// Identifies one logical request across the client, retries and the
  /// backend logs (the backend echoes it as `meta.correlationId`).
  static const String correlationId = 'X-Correlation-Id';

  /// Makes a write safe to repeat (the backend's Idempotency-Key filter).
  static const String idempotencyKey = 'Idempotency-Key';

  /// Media types the client accepts.
  static const String accept = 'Accept';

  /// JSON media type.
  static const String json = 'application/json';
}
