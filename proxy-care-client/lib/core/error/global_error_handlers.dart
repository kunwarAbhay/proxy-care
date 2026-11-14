import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';

import 'error_reporter.dart';

/// Sends uncaught errors to [reporter]: framework errors through
/// [FlutterError.onError] and asynchronous or platform errors through
/// [PlatformDispatcher.onError].
///
/// The previous framework handler still runs, so errors are still printed in
/// debug builds. Returns a callback that restores the previous handlers; tests
/// use it to clean up.
VoidCallback installGlobalErrorHandlers(ErrorReporter reporter) {
  final previousFlutterHandler = FlutterError.onError;
  final previousPlatformHandler = PlatformDispatcher.instance.onError;

  FlutterError.onError = (details) {
    reporter.report(
      details.exception,
      details.stack ?? StackTrace.empty,
      context: 'flutter',
    );
    previousFlutterHandler?.call(details);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    reporter.report(error, stackTrace, context: 'platform');
    return true;
  };

  return () {
    FlutterError.onError = previousFlutterHandler;
    PlatformDispatcher.instance.onError = previousPlatformHandler;
  };
}
