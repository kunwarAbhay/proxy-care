import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../error/global_error_handlers.dart';
import 'app_container.dart';
import 'core_providers.dart';

/// Prepares everything the app needs before the first frame and returns the
/// root [ProviderContainer]. Knows nothing about features or screens.
///
/// Steps, in order:
/// 1. Initialize Flutter bindings.
/// 2. Read and validate the environment configuration. An invalid build
///    throws `EnvConfigException` here, before anything else starts.
/// 3. Create the Riverpod container, which wires the infrastructure.
/// 4. Route uncaught framework and platform errors to the `ErrorReporter`.
///
/// Asynchronous infrastructure set-up (for example restoring a session from
/// secure storage) is added here as a later step.
Future<ProviderContainer> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final env = Env.fromEnvironment();
  final container = createAppContainer(env: env);

  installGlobalErrorHandlers(container.read(errorReporterProvider));

  return container;
}
