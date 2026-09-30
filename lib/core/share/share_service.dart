import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

/// The system share sheet behind an interface (fake in tests).
abstract interface class ShareService {
  /// Returns true when the user picked a target (false if dismissed or the
  /// platform cannot tell).
  Future<bool> shareText(String text, {String? subject, Rect? origin});
}

final class SharePlusShareService implements ShareService {
  const SharePlusShareService();

  @override
  Future<bool> shareText(String text, {String? subject, Rect? origin}) async {
    final result = await SharePlus.instance.share(
      // iPad needs an anchor rect for the popover.
      ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
    );
    return result.status == ShareResultStatus.success;
  }
}

final class FakeShareService implements ShareService {
  final List<String> shared = [];

  @override
  Future<bool> shareText(String text, {String? subject, Rect? origin}) async {
    shared.add(text);
    return true;
  }
}
