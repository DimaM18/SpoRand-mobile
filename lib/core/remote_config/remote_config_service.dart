import 'package:mobile_kit/mobile_kit.dart' as kit;

import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/remote_config/remote_config_keys.dart';

export 'package:mobile_kit/mobile_kit.dart' show BootTimings, ConfigFetchResult;

/// Typed, range-checked access to the client Remote Config: mobile_kit's
/// `RemoteConfigService` (wave 8b) over every SpoRand client key
/// ([RcKeys.all]), under the old constructor.
///
/// Reads never throw: a missing, malformed or out-of-range value falls back to
/// the bundled default (brief §4.6) or is clamped into its range. The bundled
/// defaults are usable before the SDK is ready, which is what lets the app
/// boot without Firebase config files. The game keys are read through
/// [SporandConfig]; the getters below serve receivers typed as this class.
class RemoteConfigService extends kit.RemoteConfigService {
  RemoteConfigService({required super.backend, super.defaultOverrides})
    : super(keys: RcKeys.all);

  /// See [SporandConfig.modesEnabled].
  List<GameMode> get modesEnabled => SporandConfig(this).modesEnabled;

  int get youtubePlayerMinWidthDp =>
      SporandConfig(this).youtubePlayerMinWidthDp;

  bool get spotifyProtoEnabled => SporandConfig(this).spotifyProtoEnabled;

  bool get licensedProviderEnabled =>
      SporandConfig(this).licensedProviderEnabled;
}

/// SpoRand's game keys on any kit Remote Config service (also the one
/// mobile_kit's `remoteConfigProvider` builds from `rcKeysProvider`)
/// [новое имя — согласовать].
extension SporandConfig on kit.RemoteConfigService {
  /// `modes_enabled` (wave 4): the modes the mode picker offers, in
  /// [GameMode] order.
  List<GameMode> get modesEnabled {
    final items = RcKeys.modesEnabled.itemsOf(get(RcKeys.modesEnabled));
    return [
      for (final mode in GameMode.values)
        if (items.contains(mode.wire)) mode,
    ];
  }

  /// `youtube_player_min_width_dp`: the target width of the embedded player.
  int get youtubePlayerMinWidthDp => get(RcKeys.youtubePlayerMinWidthDp);

  // Features and territories.
  bool get spotifyProtoEnabled => get(RcKeys.spotifyProtoEnabled);
  bool get licensedProviderEnabled => get(RcKeys.licensedProviderEnabled);
}
