import 'package:sporand/app/bootstrap/domain/boot_models.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/app/router/routes.dart';

/// Top-level redirect policy (pure, unit-tested).
///
/// - While booting, every location shows the splash; a deep link that
///   arrives meanwhile (cold start via universal/app link) is queued for the
///   `route` boot step instead of being lost.
/// - Force-update and maintenance gates pin the app to their screen.
/// - The age gate / onboarding comes before anything else; links opened
///   before it is done are deferred until it is.
String? guardRedirect({
  required Uri uri,
  required BootState boot,
  required bool onboardingCompleted,
  required bool ageBlocked,
  required DeepLinkQueue queue,
  required DeepLinkParser parser,
}) {
  final path = uri.path;
  if (boot is! BootCompleted) {
    if (path == Routes.boot) return null;
    if (parser.parseUri(uri) != null) queue.enqueue(UriLink(uri));
    return Routes.boot;
  }

  switch (boot.destination) {
    case ForceUpdateDestination():
      return path == Routes.forceUpdate ? null : Routes.forceUpdate;
    case MaintenanceDestination():
      return path == Routes.maintenance ? null : Routes.maintenance;
    default:
      break;
  }

  // The splash plays its hand-off animation, then navigates itself.
  if (path == Routes.boot) return null;

  if (ageBlocked) {
    return path == Routes.onboardingBlocked ? null : Routes.onboardingBlocked;
  }
  if (!onboardingCompleted) {
    if (Routes.isOnboarding(path) && path != Routes.onboardingBlocked) {
      return null;
    }
    final link = parser.parseUri(uri);
    if (link != null) queue.defer(link);
    return Routes.onboarding;
  }
  if (Routes.isOnboarding(path) || Routes.isStatusScreen(path)) {
    return Routes.home;
  }
  return null;
}
