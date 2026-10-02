import 'package:flutter/foundation.dart';
import 'package:mobile_kit/mobile_kit.dart' as kit;

import 'package:sporand/core/net/realtime_client.dart';
import 'package:sporand/core/playback/playback_adapter.dart';

// Wave 8b: the boot context is mobile_kit's (mobile-template); SpoRand's
// game services reach the game steps through `BootDependencies.project`.
export 'package:mobile_kit/mobile_kit.dart'
    show BootKey, InitContext, InitExtras;

/// The game services the SpoRand boot steps (`music_provider`, `realtime`)
/// need, handed to the kit as `projectBootServicesProvider`
/// [новое имя — согласовать].
@immutable
final class SporandBootServices {
  const SporandBootServices({required this.playback, required this.realtime});

  final PlaybackAdapter playback;
  final RealtimeClient realtime;
}

/// Every service the boot steps touch: mobile_kit's [kit.BootDependencies]
/// under the old constructor, with the game services ([playback],
/// [realtime]) as its [SporandBootServices] `project`.
class BootDependencies extends kit.BootDependencies {
  BootDependencies({
    required super.env,
    required super.appInfo,
    required super.remoteConfig,
    required super.preferences,
    required super.secureStore,
    required super.userPrefs,
    required super.sessions,
    required super.warmer,
    required super.crashReporter,
    required super.crashGate,
    required super.analytics,
    required super.consent,
    required super.appCheck,
    required super.auth,
    required super.purchases,
    required super.ads,
    required PlaybackAdapter playback,
    required RealtimeClient realtime,
    required super.linkParser,
    super.analyticsIdentity,
  }) : super(
         project: SporandBootServices(playback: playback, realtime: realtime),
       );
}

/// The game services of any [kit.BootDependencies] (the kit's, built by
/// `bootDependenciesProvider`, or the adapter above).
extension SporandBootDependencies on kit.BootDependencies {
  SporandBootServices get game => projectAs<SporandBootServices>();

  PlaybackAdapter get playback => game.playback;

  RealtimeClient get realtime => game.realtime;
}
