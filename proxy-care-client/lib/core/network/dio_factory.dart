import 'package:dio/dio.dart';

import 'authentication_session.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/correlation_id_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'network_config.dart';

/// Builds the app's configured [Dio].
///
/// Interceptor order (Dio runs request, response **and** error interceptors
/// in the order they were added; verified by `dio_factory_test.dart`):
///
/// 1. `ImplyContentTypeInterceptor` (Dio's own, always first).
/// 2. [CorrelationIdInterceptor]: every attempt, including the first, has
///    its ID before anything logs it.
/// 3. [LoggingInterceptor]: starts the timer, and in the error phase logs
///    every failed attempt (including the 401 that triggers a refresh)
///    before recovery is tried.
/// 4. [AuthInterceptor]: attaches the token just before transmission; on a
///    401, refreshes and repeats the request.
/// 5. [RetryInterceptor]: last, so it sees only failures the earlier
///    interceptors did not recover from.
///
/// Repeats from 4 and retries from 5 run through the whole chain again (new
/// token, new log line, same correlation ID) and are marked so they cannot
/// start further loops. Errors are mapped to `AppException`s once, by
/// `DioApiClient`, after the chain.
final class DioFactory {
  /// Creates a factory.
  const DioFactory({
    required this.baseUrl,
    required this.session,
    required this.log,
    this.detailedLogging = false,
    this.adapter,
    this.retryDelay,
  });

  /// The environment's API base URL.
  final Uri baseUrl;

  /// Supplies and refreshes access tokens.
  final AuthenticationSession session;

  /// Where request log lines go.
  final void Function(String message) log;

  /// Detailed (masked) request logging; debug builds only.
  final bool detailedLogging;

  /// Replaces the platform HTTP adapter (tests).
  final HttpClientAdapter? adapter;

  /// Replaces the retry backoff wait (tests).
  final RetryDelay? retryDelay;

  /// The base options for [baseUrl]: timeouts, JSON content type and the
  /// default headers.
  static BaseOptions baseOptions(Uri baseUrl) => BaseOptions(
    baseUrl: baseUrl.toString(),
    connectTimeout: NetworkConfig.connectTimeout,
    receiveTimeout: NetworkConfig.receiveTimeout,
    sendTimeout: NetworkConfig.sendTimeout,
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
    headers: {ApiHeaders.accept: ApiHeaders.json},
  );

  /// Creates a configured [Dio].
  Dio create() {
    final dio = Dio(baseOptions(baseUrl));
    if (adapter case final adapter?) dio.httpClientAdapter = adapter;
    dio.interceptors.addAll([
      CorrelationIdInterceptor(),
      LoggingInterceptor(log: log, detailed: detailedLogging),
      AuthInterceptor(session: session, dio: dio),
      RetryInterceptor(dio: dio, delay: retryDelay),
    ]);
    return dio;
  }
}
