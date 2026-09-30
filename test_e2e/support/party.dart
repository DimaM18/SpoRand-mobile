import 'package:sporand/core/ads/ads_service.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/features/lobby/presentation/lobby_controller.dart';

import 'contract_audit.dart';
import 'e2e_env.dart';
import 'e2e_phone.dart';

/// Deliberately different device clocks: OS uptime at the start of the test
/// process and the app's process anchor. The `*_mono_us` scales of any two
/// phones are hours to weeks apart.
const List<({int uptimeUs, int anchorUs})> _phoneClocks = [
  // Up for 17 minutes; the app started 7 minutes after boot.
  (uptimeUs: 1000000000, anchorUs: 400000000),
  // Up for a day.
  (uptimeUs: 86400123457, anchorUs: 3600000000),
  // Just booted.
  (uptimeUs: 7000000, anchorUs: 5000000),
  // Up for five weeks.
  (uptimeUs: 3024000000000, anchorUs: 12345),
];

/// Queries a player might type into «Мои песни» (the seed song source).
const List<String> _songQueries = ['the', 'a', 'e', 'o', 'i', 'n', 'r'];

/// Songs per player: `pool_min_tracks_per_contributor` (default 5).
const int picksPerPlayer = 5;

/// A room with its phones: [host] created it, the others joined by code.
final class Party {
  Party._(this.phones, this.audit, this._api, this._provider);

  final List<E2ePhone> phones;
  final ContractAudit audit;
  final Uri _api;
  final MusicProviderId _provider;
  final List<E2ePhone> _extras = [];

  E2ePhone get host => phones.first;

  /// Guest auth for everyone, the host creates a [mode] room with
  /// [provider], the others join by code, everyone picks
  /// [picksPerPlayer] songs through the song search and saves them, the
  /// sockets connect and sync their clocks, and everyone adds their songs to
  /// the room. Returns once the host's lobby has no start blocker.
  static Future<Party> assemble({
    required Uri api,
    required List<String> names,
    required GameMode mode,
    required MusicProviderId provider,
    required ContractAudit audit,
    Map<int, AdsService> ads = const {},
  }) async {
    final phones = [
      for (final (index, name) in names.indexed)
        E2ePhone(
          name: name,
          apiBaseUrl: api,
          uptimeAtZeroUs: _phoneClocks[index].uptimeUs,
          anchorUs: _phoneClocks[index].anchorUs,
          roomProvider: provider,
          ads: ads[index],
        ),
    ];
    for (final phone in phones) {
      audit
        ..watch(phone.wire)
        ..watchRest(phone.rest);
    }
    final party = Party._(phones, audit, api, provider);
    await Future.wait([for (final phone in phones) phone.signIn()]);
    e2eLog('guests signed in: ${[for (final p in phones) p.userId]}');

    // «Мои песни»: distinct, non-explicit songs per player (a song two
    // players own would be excluded from whose_song).
    final taken = <String>{};
    for (final phone in phones) {
      final picks = <String>[];
      for (final query in _songQueries) {
        for (final song in await phone.searchSongs(query)) {
          if (picks.length < picksPerPlayer &&
              !song.explicit &&
              taken.add(song.songId)) {
            picks.add(song.songId);
          }
        }
        if (picks.length == picksPerPlayer) break;
      }
      final saved = await phone.savePicks(picks);
      if (saved.length != picksPerPlayer) {
        throw StateError('${phone.name}: saved ${saved.length} picks');
      }
    }

    await party.host.createRoom(mode);
    final code = party.host.session.roomCode!;
    e2eLog(
      'room $code (${party.host.session.roomId}) created by ${party.host.name}',
    );
    await party.host.waitSynced();
    // One after another, like friends typing the code: everyone already in
    // the room gets `room.player_joined`.
    for (final guest in phones.skip(1)) {
      await guest.joinRoom(code);
      await guest.waitSynced();
    }
    e2eLog('all sockets connected, clocks synced');

    for (final phone in phones) {
      await phone.addMySongsToRoom();
    }
    await party.host.waitFor('a startable lobby', () {
      final state = party.host.lobbyState;
      return state is LobbyLoaded &&
              state.view.canStart &&
              state.view.players.length == phones.length
          ? state
          : null;
    });
    return party;
  }

  /// Another phone (signed in, not in the room yet) with the next clock of
  /// the list; it is audited and disposed with the party.
  Future<E2ePhone> extraPhone(String name) async {
    final index = phones.length + _extras.length;
    final phone = E2ePhone(
      name: name,
      apiBaseUrl: _api,
      uptimeAtZeroUs: _phoneClocks[index].uptimeUs,
      anchorUs: _phoneClocks[index].anchorUs,
      roomProvider: _provider,
    );
    _extras.add(phone);
    audit
      ..watch(phone.wire)
      ..watchRest(phone.rest);
    await phone.signIn();
    return phone;
  }

  E2ePhone byPlayerId(String playerId) =>
      phones.firstWhere((p) => p.playerId == playerId);

  /// The host's «Начать игру».
  void start() => host.lobby.startGame();

  Future<void> dispose() async {
    for (final phone in [...phones, ..._extras]) {
      await phone.dispose();
    }
  }
}
