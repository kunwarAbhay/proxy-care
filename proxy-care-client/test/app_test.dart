import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/app.dart';
import 'package:proxy_care_client/core/config/env.dart';

void main() {
  testWidgets('ProxyCareApp uses the configured app name', (tester) async {
    final env = Env.parse(
      appEnv: '',
      apiBaseUrl: '',
      appName: 'Proxy Care Test',
      enableLogging: '',
      featureFlags: '',
    );

    await tester.pumpWidget(ProxyCareApp(env: env));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Proxy Care Test');
    expect(tester.takeException(), isNull);
  });
}
