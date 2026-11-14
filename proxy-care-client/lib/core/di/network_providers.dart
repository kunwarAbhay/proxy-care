import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/authentication_session.dart';
import '../network/dio_api_client.dart';
import '../network/dio_factory.dart';
import '../network/response_parser.dart';
import 'core_providers.dart';

// Networking providers. Only the data layer reads `apiClientProvider`;
// `dioProvider` is for the networking layer itself.

/// The signed-in session that supplies tokens. Signed out until the
/// authentication milestone overrides it.
final authenticationSessionProvider = Provider<AuthenticationSession>(
  (ref) => const SignedOutSession(),
);

/// The configured Dio. Closed when the container is disposed.
final dioProvider = Provider<Dio>((ref) {
  final logger = ref.watch(loggerProvider);
  final dio = DioFactory(
    baseUrl: ref.watch(envProvider).apiBaseUrl,
    session: ref.watch(authenticationSessionProvider),
    log: (message) => logger.i(message),
    detailedLogging: kDebugMode,
  ).create();
  ref.onDispose(dio.close);
  return dio;
});

/// The app's API client.
final apiClientProvider = Provider<ApiClient>((ref) {
  final errorMapper = ref.watch(errorMapperProvider);
  return DioApiClient(
    ref.watch(dioProvider),
    errorMapper: errorMapper,
    parser: ResponseParser(errorMapper: errorMapper),
  );
});
