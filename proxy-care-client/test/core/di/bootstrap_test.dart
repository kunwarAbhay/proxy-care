import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/config/app_environment.dart';
import 'package:proxy_care_client/core/di/bootstrap.dart';
import 'package:proxy_care_client/core/di/core_providers.dart';

void main() {
  // Use the test binding so bootstrap's ensureInitialized reuses it.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bootstrap loads env, builds the container, wires errors', () async {
    final previousFlutterHandler = FlutterError.onError;
    final previousPlatformHandler = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = previousFlutterHandler;
      PlatformDispatcher.instance.onError = previousPlatformHandler;
    });

    final container = await bootstrap();
    addTearDown(container.dispose);

    // Tests run without --dart-define, so the development defaults apply.
    expect(
      container.read(envProvider).environment,
      AppEnvironment.development,
    );
    expect(FlutterError.onError, isNot(same(previousFlutterHandler)));
    expect(PlatformDispatcher.instance.onError, isNotNull);
  });
}
