import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/config/env.dart';

void main() {
  // Fails fast with an EnvConfigException if the build was given an invalid
  // configuration, instead of starting against the wrong backend.
  final env = Env.fromEnvironment();
  runApp(ProxyCareApp(env: env));
}
