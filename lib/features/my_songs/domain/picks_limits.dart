import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';

/// How many songs «Мои песни» holds: the protocol bounds of
/// `PUT /v1/me/picks` (5–10), narrowed by the room's
/// `pool_min_tracks_per_contributor` / `pool_max_tracks_per_contributor`
/// when a room config is known. [новое имя — согласовать] `PicksLimits`.
final class PicksLimits {
  const PicksLimits({required this.min, required this.max});

  factory PicksLimits.of(RoomConfig? config) {
    if (config == null) return defaults;
    final min = config.poolMinTracksPerContributor.clamp(
      PicksUpdateRequest.minPicks,
      PicksUpdateRequest.maxPicks,
    );
    final max = config.poolMaxTracksPerContributor.clamp(
      min,
      PicksUpdateRequest.maxPicks,
    );
    return PicksLimits(min: min, max: max);
  }

  static const defaults = PicksLimits(
    min: PicksUpdateRequest.minPicks,
    max: PicksUpdateRequest.maxPicks,
  );

  final int min;
  final int max;
}
