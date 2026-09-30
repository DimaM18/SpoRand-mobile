import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/app/router/routes.dart';

final homeControllerProvider = Provider<HomeController>(HomeController.new);

class HomeController {
  HomeController(this._ref);

  final Ref _ref;

  /// Normalizes a typed room code (Crockford base32, 6 chars) into the join
  /// route, or null if it cannot be a room code.
  String? joinLocation(String input) {
    final code = DeepLinkParser.normalizeRoomCode(input);
    return code == null ? null : Routes.join(code, via: JoinVia.code.wire);
  }

  /// Returning users whose UMP consent must be renewed see the form once
  /// after boot, never over the splash (brief §3 `consent` step).
  Future<void> showConsentFormIfRequired() async {
    final consent = _ref.read(consentServiceProvider);
    if (!consent.current.formRequired) return;
    try {
      await consent.showFormIfRequired();
    } on Object {
      // Ads simply stay off until the next attempt.
    }
  }
}
