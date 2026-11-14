import 'package:dio/dio.dart';

import '../authentication_session.dart';
import '../network_config.dart';
import '../request_options.dart';

/// Attaches the access token and recovers from an expired one.
///
/// * Request: adds `Authorization: Bearer <token>` when the session has a
///   token, unless the request was sent with `skipAuth`.
/// * 401 response: asks the session to refresh and, if it returns a new
///   token, repeats the request once with it. If refreshing fails, the 401
///   continues and becomes `UnauthorizedException`.
///
/// Recursion is impossible: refresh calls are sent with `skipAuth` (never
/// intercepted), and a repeated request is marked so a second 401 is not
/// refreshed again. Sharing one refresh between concurrent 401s is the
/// session's responsibility (authentication milestone).
final class AuthInterceptor extends Interceptor {
  /// Creates the interceptor. [dio] repeats requests after a refresh.
  AuthInterceptor({required this.session, required this.dio});

  /// Supplies and refreshes tokens.
  final AuthenticationSession session;

  /// Repeats requests after a refresh.
  final Dio dio;

  static const String _bearer = 'Bearer ';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[RequestExtra.skipAuth] == true) {
      options.headers.remove(ApiHeaders.authorization);
      handler.next(options);
      return;
    }
    final token = await session.accessToken();
    if (token != null && token.isNotEmpty) {
      options.headers[ApiHeaders.authorization] = '$_bearer$token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final shouldRefresh =
        err.response?.statusCode == 401 &&
        options.extra[RequestExtra.skipAuth] != true &&
        options.extra[RequestExtra.authRetried] != true;
    if (!shouldRefresh) {
      handler.next(err);
      return;
    }

    final sent = options.headers[ApiHeaders.authorization] as String?;
    final rejected = sent != null && sent.startsWith(_bearer)
        ? sent.substring(_bearer.length)
        : null;

    final String? token;
    try {
      token = await session.refreshAccessToken(rejectedToken: rejected);
    } on Object {
      // A failed refresh leaves the original 401 as the outcome.
      handler.next(err);
      return;
    }
    if (token == null || token.isEmpty) {
      handler.next(err);
      return;
    }

    options.extra[RequestExtra.authRetried] = true;
    // A multipart body can be sent once; the repeat needs a fresh copy.
    if (options.data case final FormData form) options.data = form.clone();
    try {
      // The repeat runs the whole chain again; this interceptor attaches
      // the new token from the session.
      handler.resolve(await dio.fetch<Object?>(options));
    } on DioException catch (repeatError) {
      handler.next(repeatError);
    }
  }
}
