import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proxy_care_client/app.dart';
import 'package:proxy_care_client/core/di/core_providers.dart';

import 'fixtures/env_fixtures.dart';

void main() {
  testWidgets('ProxyCareApp uses the configured app name', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          envProvider.overrideWithValue(testEnv(appName: 'Proxy Care Test')),
        ],
        child: const ProxyCareApp(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Proxy Care Test');
    expect(tester.takeException(), isNull);
  });
}
