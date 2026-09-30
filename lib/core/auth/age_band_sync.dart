import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/storage/user_prefs_repository.dart';

/// Tells the server the age band from the onboarding age gate
/// (`PATCH /v1/me {age_band}`, brief §4.2, §7). [новое имя — согласовать]
///
/// The server decides with `users.age_band` whether a room forces the
/// explicit filter (every band but `18_plus`, unknown included) and whether a
/// player may be offered the rewarded bonus or an interstitial (unknown:
/// never). It reads the band when a player creates or joins a room, so
/// `ActiveRoomController` calls [ensureSynced] right before both. The server
/// takes the band only while the account has none, so it is sent once per
/// account (`user_id`), and a 409 means the server already has one.
final class AgeBandSync {
  AgeBandSync({
    required this._client,
    required this._prefs,
    required this._currentUserId,
  });

  final ApiClient? _client;
  final UserPrefsRepository _prefs;
  final Future<String> Function() _currentUserId;

  /// Never throws and waits at most [maxWait], so a slow network cannot hold
  /// up opening the room: a sync that failed (or is still running) is
  /// retried before the next create or join, and meanwhile the server treats
  /// the age as unknown.
  Future<void> ensureSynced({Duration maxWait = const Duration(seconds: 3)}) =>
      _sync().timeout(maxWait, onTimeout: () {});

  Future<void> _sync() async {
    final client = _client;
    final band = _prefs.ageBand;
    if (client == null || band == null || band.isBlocked) return;
    try {
      final userId = await _currentUserId();
      if (_prefs.ageBandSyncedFor == userId) return;
      try {
        await client.patch(
          '/v1/me',
          body: MePatchRequest(ageBand: band).toJson(),
        );
      } on ApiError catch (e) {
        if (e.status != 409) return;
      }
      await _prefs.markAgeBandSynced(userId);
    } on Object {
      return;
    }
  }
}
