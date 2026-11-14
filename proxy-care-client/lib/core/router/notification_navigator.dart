import 'package:go_router/go_router.dart';

import 'deep_link_policy.dart';
import 'intended_destination.dart';
import 'navigation_payload.dart';

/// The outcome of [NotificationNavigator.open].
enum NotificationNavigationOutcome {
  /// The router was sent to the payload's location (guards still apply).
  navigated,

  /// The payload failed validation.
  invalidPayload,

  /// No module handles the payload type.
  unknownType,

  /// The resolver produced no safe location.
  unresolved,
}

/// The entry point for opening notification taps (and other external
/// navigation requests) in the router. Push delivery is not part of the
/// app yet: a future push integration passes each tapped payload to
/// [open], at a cold start or while running.
///
/// The navigator validates the payload, asks the owning module's resolver
/// for a location (built from path parameters, so it rebuilds fully after
/// a cold start) and calls `go`. The router's guards then apply as for any
/// navigation: a protected target while signed out goes to sign-in with
/// the target preserved.
final class NotificationNavigator {
  /// Creates the navigator.
  const NotificationNavigator({
    required this.router,
    required this.resolvers,
    required this.deepLinks,
  });

  /// Payload type that opens a link: `data.link` holds an in-app path or an
  /// accepted deep-link URL.
  static const openLinkType = 'router.openLink';

  /// The app router.
  final GoRouter router;

  /// Resolvers by payload type (from `RouteRegistry`).
  final Map<String, NotificationLocationResolver> resolvers;

  /// Which links [openLinkType] payloads may open.
  final DeepLinkPolicy deepLinks;

  /// Validates [rawPayload] and navigates to its location.
  NotificationNavigationOutcome open(Object? rawPayload) {
    final payload = NavigationPayload.tryParse(rawPayload);
    if (payload == null) return NotificationNavigationOutcome.invalidPayload;

    final String? location;
    if (payload.type == openLinkType) {
      final link = Uri.tryParse(payload.data['link'] ?? '');
      location = link == null ? null : deepLinks.resolve(link);
    } else {
      final resolver = resolvers[payload.type];
      if (resolver == null) return NotificationNavigationOutcome.unknownType;
      location = IntendedDestination.sanitize(resolver(payload));
    }
    if (location == null) return NotificationNavigationOutcome.unresolved;

    router.go(location);
    return NotificationNavigationOutcome.navigated;
  }
}
