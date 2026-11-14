import 'package:proxy_care_client/core/network/authentication_session.dart';
import 'package:proxy_care_client/core/network/dio_api_client.dart';
import 'package:proxy_care_client/core/network/dio_factory.dart';

import 'fake_http_adapter.dart';

/// A session with controllable tokens that counts refreshes.
final class FakeSession implements AuthenticationSession {
  FakeSession({this.token, this.refreshedToken});

  /// Returned by [accessToken].
  String? token;

  /// Returned (and stored as [token]) by [refreshAccessToken].
  String? refreshedToken;

  /// Tokens passed to [refreshAccessToken].
  final List<String?> refreshes = [];

  @override
  Future<String?> accessToken() async => token;

  @override
  Future<String?> refreshAccessToken({required String? rejectedToken}) async {
    refreshes.add(rejectedToken);
    token = refreshedToken;
    return refreshedToken;
  }
}

/// The real networking stack (factory, interceptors, client) over a
/// [FakeHttpAdapter]: no network, no real waiting.
final class NetworkHarness {
  NetworkHarness({
    List<FakeResponder> responses = const [],
    AuthenticationSession? session,
    this.detailedLogging = false,
  }) : adapter = FakeHttpAdapter(responses),
       session = session ?? FakeSession() {
    final dio = DioFactory(
      baseUrl: Uri.parse('https://api.proxycare.test'),
      session: this.session,
      log: logs.add,
      detailedLogging: detailedLogging,
      adapter: adapter,
      retryDelay: (delay) async => delays.add(delay),
    ).create();
    client = DioApiClient(dio);
  }

  final FakeHttpAdapter adapter;
  final AuthenticationSession session;
  final bool detailedLogging;

  /// Log lines written by the logging interceptor.
  final List<String> logs = [];

  /// Backoff delays the retry interceptor asked for.
  final List<Duration> delays = [];

  late final DioApiClient client;
}
