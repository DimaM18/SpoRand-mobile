import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/router/routes.dart';
import 'package:sporand/core/analytics/analytics_events.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/net/ws_client.dart';
import 'package:sporand/features/lobby/data/rooms_api.dart';
import 'package:sporand/features/lobby/domain/room_session.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';
import 'package:sporand/features/my_songs/domain/picks_limits.dart';
import 'package:sporand/features/my_songs/presentation/my_songs_controller.dart';

final class LobbyPlayer {
  const LobbyPlayer({
    required this.playerId,
    required this.name,
    required this.isHost,
    required this.isMe,
    required this.ready,
    required this.connection,
    required this.isContributor,
    required this.poolTrackCount,
    this.canDj = false,
  });

  final String playerId;
  final String name;
  final bool isHost;
  final bool isMe;
  final bool ready;
  final PlayerConnection connection;
  final bool isContributor;
  final int poolTrackCount;

  /// Opted in to the DJ role (`PlayerSnapshot.can_dj`).
  final bool canDj;
}

/// A rounds choice; premium ones are locked for a free host (paywall
/// placement `lobby_rounds`).
final class RoundsChoice {
  const RoundsChoice(this.rounds, {required this.locked});

  final int rounds;
  final bool locked;
}

/// What still blocks `game.start` (a client hint; the server validates).
sealed class StartBlocker {
  const StartBlocker();
}

final class NeedMorePlayers extends StartBlocker {
  const NeedMorePlayers(this.minimum);

  final int minimum;
}

/// whose_song: fewer than `whose_song_min_contributors` players have a pool
/// of at least `pool_min_tracks_per_contributor` songs.
final class NeedContributors extends StartBlocker {
  const NeedContributors(this.missing);

  final int missing;
}

/// A contributor's pool is below `pool_min_tracks_per_contributor`
/// («У Ани меньше 5 треков», design doc S1.8.4).
final class PoolTooSmall extends StartBlocker {
  const PoolTooSmall({required this.name, required this.minimum});

  final String name;
  final int minimum;
}

/// guess_track from player pools: nobody has added songs yet.
final class NeedAnyPool extends StartBlocker {
  const NeedAnyPool();
}

/// What «Добавить мои песни» found in «Мои песни» for this room.
sealed class PoolDraft {
  const PoolDraft();
}

/// Ready for the consent step: exactly these picks become the pool.
final class PoolReady extends PoolDraft {
  const PoolReady(this.picks);

  final List<CatalogPick> picks;
}

/// Fewer than [minimum] usable picks: open «Мои песни» first.
final class PoolNeedsPicks extends PoolDraft {
  const PoolNeedsPicks(this.minimum);

  final int minimum;
}

final class PoolUnavailable extends PoolDraft {
  const PoolUnavailable();
}

final class LobbyView {
  const LobbyView({
    required this.roomCode,
    required this.joinLink,
    required this.players,
    required this.isHost,
    required this.meReady,
    required this.mode,
    required this.roundsTotal,
    required this.roundChoices,
    required this.hostTier,
    required this.reconnecting,
    required this.contributorsNeeded,
    this.startBlocker,
    this.collectsPools = false,
    this.myPoolTrackCount = 0,
    this.poolMinTracks = 5,
    this.isDjHost = false,
    this.showsDj = false,
    this.meCanDj = false,
    this.emojiMarkets = EmojiMarket.values,
    this.emojiMaxDifficulty = EmojiDifficulty.defaultMax,
  });

  final String roomCode;

  /// `https://<domain>/j/{room_code}`; null when no link host is configured.
  final Uri? joinLink;
  final List<LobbyPlayer> players;
  final bool isHost;
  final bool meReady;
  final GameMode mode;
  final int roundsTotal;
  final List<RoundsChoice> roundChoices;
  final HostTier hostTier;
  final bool reconnecting;

  /// whose_song: contributors still missing (0 when enough).
  final int contributorsNeeded;
  final StartBlocker? startBlocker;

  /// The room plays players' own songs (`catalog_picks`): show «Добавить мои
  /// песни».
  final bool collectsPools;

  /// Songs of this player's pool in the room (`pool_track_count`).
  final int myPoolTrackCount;

  /// `pool_min_tracks_per_contributor`.
  final int poolMinTracks;

  /// The host of an external_player room is the DJ of every round (A2.2,
  /// no `byop_dj_rotation`).
  final bool isDjHost;

  /// A BYOP room that plays songs: the «Могу включать музыку» toggle and
  /// the DJ badges are shown.
  final bool showsDj;

  /// This player's `can_dj`.
  final bool meCanDj;

  /// emoji_quiz: the markets the room draws from (the server's effective
  /// choice; both when it sent none).
  final List<EmojiMarket> emojiMarkets;

  /// emoji_quiz: `emoji_max_difficulty` (1-3).
  final int emojiMaxDifficulty;

  bool get isEmojiQuiz => mode == GameMode.emojiQuiz;

  bool get canStart => isHost && startBlocker == null;

  /// The QR code carries `via=qr` for `room_join.via`.
  Uri? get qrLink => joinLink?.replace(queryParameters: {'via': 'qr'});
}

sealed class LobbyUiState {
  const LobbyUiState();
}

final class LobbyNoRoom extends LobbyUiState {
  const LobbyNoRoom();
}

final class LobbyConnecting extends LobbyUiState {
  const LobbyConnecting(this.roomCode);

  final String? roomCode;
}

final class LobbyLoaded extends LobbyUiState {
  const LobbyLoaded(this.view);

  final LobbyView view;
}

final lobbyControllerProvider = NotifierProvider<LobbyController, LobbyUiState>(
  LobbyController.new,
);

class LobbyController extends Notifier<LobbyUiState> {
  RoomSession? _session;

  @override
  LobbyUiState build() {
    final session = ref.watch(roomSessionProvider);
    _session = session;
    if (session == null) return const LobbyNoRoom();
    final subs = [
      session.roomChanges.listen((_) => state = _compute(session)),
      session.connection.listen((_) => state = _compute(session)),
    ];
    ref.onDispose(() {
      for (final sub in subs) {
        unawaited(sub.cancel());
      }
    });
    return _compute(session);
  }

  LobbyUiState _compute(RoomSession session) {
    final room = session.room;
    if (room == null) return LobbyConnecting(session.roomCode);
    final config = session.config;
    final premiumHost = room.hostTier == HostTier.premium;
    final premiumOptions = config.roundsPremiumOptions;
    final freeOptions = config.roundsFreeOptions;
    final choices = [
      for (final rounds in {...freeOptions, ...premiumOptions}.toList()..sort())
        RoundsChoice(
          rounds,
          locked: !premiumHost && !freeOptions.contains(rounds),
        ),
    ];
    final me = session.playerId;
    final players = [
      for (final p in room.players)
        LobbyPlayer(
          playerId: p.playerId,
          name: p.displayName,
          isHost: p.playerId == room.hostPlayerId,
          isMe: p.playerId == me,
          ready: p.ready,
          connection: p.connection,
          isContributor: p.isContributor,
          poolTrackCount: p.poolTrackCount,
          canDj: p.canDj,
        ),
    ]..sort((a, b) => a.isHost == b.isHost ? 0 : (a.isHost ? -1 : 1));
    final present = players
        .where((p) => p.connection != PlayerConnection.left)
        .toList();
    // Brief §2: guess_track needs 2 players; whose_song needs 3
    // contributors; emoji_quiz needs 2 players and no pools. A client hint
    // only: the server checks the pools and the catalogue.
    final mode = room.settings.mode;
    final minPlayers = room.mode == GameMode.whoseSong
        ? config.whoseSongMinContributors
        : 2;
    final poolMin = config.poolMinTracksPerContributor;
    final collectsPools =
        mode.usesPools &&
        room.settings.poolSources.contains(PoolSource.catalogPicks);
    final byop = room.capabilities.isExternalApp && mode.usesPools;
    final contributors = present
        .where((p) => p.poolTrackCount >= poolMin)
        .length;
    final tooSmall = present
        .where((p) => p.poolTrackCount > 0 && p.poolTrackCount < poolMin)
        .toList();
    final contributorsNeeded = room.mode == GameMode.whoseSong
        ? (config.whoseSongMinContributors - contributors).clamp(0, 99)
        : 0;
    final StartBlocker? blocker = present.length < minPlayers
        ? NeedMorePlayers(minPlayers)
        : contributorsNeeded > 0
        ? (tooSmall.isEmpty
              ? NeedContributors(contributorsNeeded)
              : PoolTooSmall(name: tooSmall.first.name, minimum: poolMin))
        : room.mode == GameMode.guessTrack &&
              collectsPools &&
              !room.settings.poolSources.contains(PoolSource.catalogPack) &&
              contributors == 0
        ? const NeedAnyPool()
        : null;
    final code = session.roomCode ?? room.roomCode ?? '';
    final linkHosts = ref.read(appEnvProvider).linkHosts;
    return LobbyLoaded(
      LobbyView(
        roomCode: code,
        joinLink: linkHosts.isEmpty || code.isEmpty
            ? null
            : Uri(
                scheme: 'https',
                host: linkHosts.first,
                path: Routes.join(code),
              ),
        players: players,
        isHost: session.isHost,
        meReady: room.player(me)?.ready ?? false,
        mode: room.settings.mode,
        roundsTotal: room.settings.roundsTotal,
        roundChoices: choices,
        hostTier: room.hostTier,
        reconnecting: session.ws.state is! WsConnected,
        contributorsNeeded: contributorsNeeded,
        startBlocker: blocker,
        collectsPools: collectsPools,
        myPoolTrackCount: room.player(me)?.poolTrackCount ?? 0,
        poolMinTracks: poolMin,
        isDjHost: session.isHost && byop && !config.byopDjRotation,
        showsDj: byop,
        meCanDj: room.player(me)?.canDj ?? session.isHost,
        emojiMarkets: room.settings.emojiMarkets ?? EmojiMarket.values,
        emojiMaxDifficulty:
            room.settings.emojiMaxDifficulty ?? EmojiDifficulty.defaultMax,
      ),
    );
  }

  LobbyView? get _view => switch (state) {
    LobbyLoaded(:final view) => view,
    _ => null,
  };

  void toggleReady() {
    final view = _view;
    if (view == null) return;
    _session?.send(LobbyReady(ready: !view.meReady));
  }

  void setMode(GameMode mode) {
    final room = _session?.room;
    if (room == null || !(_session?.isHost ?? false)) return;
    var sources = room.settings.poolSources;
    // whose_song needs players' own pools, not a curated pack.
    if (mode == GameMode.whoseSong &&
        sources.every((s) => s == PoolSource.catalogPack)) {
      sources = const [PoolSource.catalogPicks];
    }
    _sendSettings(room.settings, mode: mode, poolSources: sources);
  }

  /// Returns false when [rounds] needs Premium (the UI opens the paywall
  /// with placement `lobby_rounds`).
  bool setRounds(int rounds) {
    final view = _view;
    final room = _session?.room;
    if (view == null || room == null || !view.isHost) return true;
    final choice = view.roundChoices.where((c) => c.rounds == rounds);
    if (choice.isEmpty) return true;
    if (choice.first.locked) return false;
    _sendSettings(room.settings, roundsTotal: rounds);
    return true;
  }

  /// emoji_quiz: turns [market] on or off; the last market stays on.
  void toggleEmojiMarket(EmojiMarket market) {
    final view = _view;
    final room = _session?.room;
    if (view == null || room == null || !view.isHost) return;
    final current = view.emojiMarkets;
    final next = current.contains(market)
        ? [
            for (final m in current)
              if (m != market) m,
          ]
        : [...current, market];
    if (next.isEmpty) return;
    _sendSettings(room.settings, emojiMarkets: next);
  }

  /// emoji_quiz: the hardest puzzles to play (1-3).
  void setEmojiMaxDifficulty(int difficulty) {
    final view = _view;
    final room = _session?.room;
    if (view == null || room == null || !view.isHost) return;
    if (difficulty < EmojiDifficulty.min || difficulty > EmojiDifficulty.max) {
      return;
    }
    _sendSettings(room.settings, emojiMaxDifficulty: difficulty);
  }

  /// «Могу включать музыку» (`lobby.set_can_dj`); the server echoes it in
  /// `room.player_updated`.
  void setCanDj(bool canDj) {
    if (_view == null) return;
    _session?.send(LobbySetCanDj(canDj: canDj));
  }

  void _sendSettings(
    RoomSettings current, {
    GameMode? mode,
    int? roundsTotal,
    List<PoolSource>? poolSources,
    List<EmojiMarket>? emojiMarkets,
    int? emojiMaxDifficulty,
  }) {
    final nextMode = mode ?? current.mode;
    // The emoji settings only mean something in emoji_quiz; there they are
    // kept unless changed (omitted = the server's locale default).
    final emoji = nextMode == GameMode.emojiQuiz;
    _session?.send(
      LobbyUpdateSettings(
        mode: nextMode,
        roundsTotal: roundsTotal ?? current.roundsTotal,
        shuffleStrategy: current.shuffleStrategy,
        explicitFilter: current.explicitFilter,
        poolSources: poolSources ?? current.poolSources,
        packId: current.packId,
        emojiMarkets: emoji ? emojiMarkets ?? current.emojiMarkets : null,
        emojiMaxDifficulty: emoji
            ? emojiMaxDifficulty ?? current.emojiMaxDifficulty
            : null,
      ),
    );
  }

  void startGame() {
    if (_view?.canStart ?? false) _session?.send(const GameStart());
  }

  /// «Добавить мои песни», step 1: the picks of «Мои песни» this room can
  /// use (song picks for external_player / none, legacy catalogue picks for
  /// catalogue providers), for the «Что увидят друзья» consent step.
  Future<PoolDraft> preparePool() async {
    final session = _session;
    final room = session?.room;
    if (session == null || room == null) return const PoolUnavailable();
    final limits = PicksLimits.of(session.config);
    final List<CatalogPick> picks;
    try {
      picks = await ref.read(mySongsApiProvider).picks();
    } on Object {
      return const PoolUnavailable();
    }
    final usable = [
      for (final pick in picks)
        if (room.provider.usesSongIds
            ? pick is SongPick
            : pick is LegacyCatalogPick)
          pick,
    ].take(limits.max).toList();
    if (usable.length < limits.min) return PoolNeedsPicks(limits.min);
    return PoolReady(usable);
  }

  /// Step 2, after the player confirmed «Эти песни будут показаны комнате
  /// как ваши»: `PUT /v1/rooms/{room_id}/pool`. The server then updates
  /// `pool_track_count` with `room.player_updated`.
  Future<bool> submitPool(PoolReady draft) async {
    final session = _session;
    if (session == null) return false;
    final pool = PoolPutRequest(
      poolSource: PoolSource.catalogPicks,
      tracks: [
        for (final (index, pick) in draft.picks.indexed)
          switch (pick) {
            SongPick(:final song) => SongPoolTrack(
              songId: song.songId,
              rank: index + 1,
            ),
            LegacyCatalogPick(:final track) => CatalogPoolTrack(
              catalogTrackId: track.catalogTrackId,
              rank: index + 1,
            ),
          },
      ],
    );
    try {
      await ref
          .read(roomsApiProvider)
          .submitPool(roomId: session.roomId, pool: pool);
      return true;
    } on Object {
      return false;
    }
  }

  void kick(String playerId) {
    if (_session?.isHost ?? false) {
      _session?.send(LobbyKick(playerId: playerId));
    }
  }

  /// `POST /v1/rooms/{room_id}/reports` + `report_player`.
  Future<bool> report(String playerId, ReportReason reason) async {
    final session = _session;
    if (session == null) return false;
    try {
      await ref
          .read(roomsApiProvider)
          .reportPlayer(
            roomId: session.roomId,
            playerId: playerId,
            reason: reason,
          );
    } on Object {
      return false;
    }
    unawaited(
      ref.read(analyticsProvider).logEvent(AnalyticsEvents.reportPlayer, {
        AnalyticsParams.reason: reason.wire,
      }),
    );
    return true;
  }

  /// System share sheet + `room_share{channel}`.
  Future<void> share(String text) async {
    final shared = await ref.read(shareServiceProvider).shareText(text);
    if (shared) _logShare('share_sheet');
  }

  void linkCopied() => _logShare('copy_link');

  void _logShare(String channel) => unawaited(
    ref.read(analyticsProvider).logEvent(AnalyticsEvents.roomShare, {
      AnalyticsParams.channel: channel,
    }),
  );
}

/// `error` messages of the current room, for snackbars.
final roomErrorsProvider = StreamProvider<ServerError>((ref) {
  final session = ref.watch(roomSessionProvider);
  return session?.errors ?? const Stream<ServerError>.empty();
});
