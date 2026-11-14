import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/di/core_providers.dart';

/// Root widget of the Proxy Care client.
///
/// Reads its configuration from Riverpod, so it must sit under a
/// `ProviderScope` (or `UncontrolledProviderScope`) that overrides
/// `envProvider`. Deliberately renders nothing yet: routing, theming and
/// screens are added in later milestones.
class ProxyCareApp extends ConsumerWidget {
  /// Creates the root widget.
  const ProxyCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appName = ref.watch(envProvider.select((env) => env.appName));
    return MaterialApp(
      title: appName,
      builder: (_, _) => const SizedBox.shrink(),
    );
  }
}
