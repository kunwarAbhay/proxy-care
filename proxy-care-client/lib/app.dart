import 'package:flutter/material.dart';

import 'core/config/env.dart';

/// Root widget of the Proxy Care client.
///
/// Deliberately renders nothing yet: routing, theming and screens are added
/// in later milestones.
class ProxyCareApp extends StatelessWidget {
  /// Creates the root widget for the given [env].
  const ProxyCareApp({required this.env, super.key});

  /// Validated configuration for this build.
  final Env env;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: env.appName,
      builder: (_, _) => const SizedBox.shrink(),
    );
  }
}
