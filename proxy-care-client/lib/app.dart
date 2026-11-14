import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/di/core_providers.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/theme/theme_providers.dart';

/// Root widget of the Proxy Care client.
///
/// Reads its configuration from Riverpod, so it must sit under a
/// `ProviderScope` (or `UncontrolledProviderScope`) that overrides
/// `envProvider`. Applies the Proxy Care theme; deliberately renders no
/// screen yet: routing and screens are added in later milestones.
class ProxyCareApp extends ConsumerWidget {
  /// Creates the root widget.
  const ProxyCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appName = ref.watch(envProvider.select((env) => env.appName));
    return MaterialApp(
      title: appName,
      theme: ref.watch(appThemeProvider),
      themeMode: ref.watch(appThemeModeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (_, _) => const SizedBox.shrink(),
    );
  }
}
