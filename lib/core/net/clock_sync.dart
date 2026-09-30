import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';

/// The client's view of clock sync (brief §5 "Clock sync"). The server runs
/// the Cristian/NTP exchange (the client only answers `clock.ping`) and sends
/// `clock.result` after each burst; this model keeps the latest one.
///
/// Convention: device clock ≈ server clock + offset, i.e.
/// `mono_us = server_us + offset_us`.
final class ClockModel {
  ClockResult? _latest;
  bool _stale = false;

  ClockResult? get latest => _latest;

  /// A result is known and still valid for this wake period.
  bool get isSynced => _latest != null && !_stale;

  ClockQuality? get quality => _latest?.quality;

  int? get offsetUs => _latest?.offsetUs;

  /// Half the best round trip: the expected conversion error bound.
  int? get errorBoundUs {
    final rtt = _latest?.rttMinUs;
    return rtt == null ? null : rtt ~/ 2;
  }

  void apply(ClockResult result) {
    _latest = result;
    _stale = false;
  }

  /// After the device sleeps (app back in the foreground) the old offset is
  /// invalid until the server's new burst produces a fresh `clock.result`.
  /// The last value is still used as a best guess meanwhile.
  void markStale() => _stale = true;

  /// `*_server_ms` -> `*_mono_us`. Null before the first `clock.result`.
  int? serverMsToMonoUs(int serverMs) {
    final offset = _latest?.offsetUs;
    return offset == null ? null : serverMs * 1000 + offset;
  }

  /// `*_mono_us` -> `*_server_ms` (the server's `tap_server_ms` formula).
  int? monoUsToServerMs(int monoUs) {
    final offset = _latest?.offsetUs;
    return offset == null ? null : ((monoUs - offset) / 1000).round();
  }
}
