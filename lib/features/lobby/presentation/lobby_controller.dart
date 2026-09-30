import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/router/routes.dart';
import 'package:sporand/core/analytics/analytics_events.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/net/ws_client.dart';
import 'package:sporand/features/lobby/data/rooms_api.dart';
import 'package:sporand/features/lobby/domain/room_session.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';

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
  });

  final String playerId;
  final String name;
  final bool isHost;
  final bool isMe;
  final bool ready;
  final PlayerConnection connection;
  final bool isContributor;
  final int poolTrackCount;
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
        ),
    ]..sort((a, b) => a.isHost == b.isHost ? 0 : (a.isHost ? -1 : 1));
    final present = players
        .where((p) => p.connection != PlayerConnection.left)
        .length;
    // Brief §2: guess_track needs 2 players; whose_song needs 3
    // contributors (checked by the server against their pools).
    final minPlayers = room.mode == GameMode.whoseSong
        ? config.whoseSongMinContributors
        : 2;
    final contributors = players.where((p) => p.isContributor).length;
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
        contributorsNeeded: room.mode == GameMode.whoseSong
            ? (config.whoseSongMinContributors - contributors).clamp(0, 99)
            : 0,
        startBlocker: present < minPlayers ? NeedMorePlayers(minPlayers) : null,
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

  void _sendSettings(
    RoomSettings current, {
    GameMode? mode,
    int? roundsTotal,
    List<PoolSource>? poolSources,
  }) {
    _session?.send(
      LobbyUpdateSettings(
        mode: mode ?? current.mode,
        roundsTotal: roundsTotal ?? current.roundsTotal,
        shuffleStrategy: current.shuffleStrategy,
        explicitFilter: current.explicitFilter,
        poolSources: poolSources ?? current.poolSources,
        packId: current.packId,
      ),
    );
  }

  void startGame() {
    if (_view?.canStart ?? false) _session?.send(const GameStart());
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
