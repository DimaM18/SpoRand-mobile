import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/router/routes.dart';
import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/app/widgets/qr_code_view.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/features/lobby/data/rooms_api.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';
import 'package:sporand/features/lobby/presentation/lobby_controller.dart';
import 'package:sporand/features/lobby/presentation/room_route_sync.dart';
import 'package:sporand/features/paywall/domain/paywall_placement.dart';

String gameModeLabel(AppLocalizations l10n, GameMode mode) => switch (mode) {
  GameMode.whoseSong => l10n.modeWhoseSong,
  GameMode.guessTrack => l10n.modeGuessTrack,
  GameMode.emojiQuiz => l10n.modeEmojiQuiz,
};

String emojiMarketLabel(AppLocalizations l10n, EmojiMarket market) =>
    switch (market) {
      EmojiMarket.intl => l10n.lobbyEmojiMarketIntl,
      EmojiMarket.pl => l10n.lobbyEmojiMarketPl,
    };

String emojiDifficultyLabel(AppLocalizations l10n, int difficulty) =>
    switch (difficulty) {
      1 => l10n.lobbyEmojiDifficultyEasy,
      2 => l10n.lobbyEmojiDifficultyMedium,
      _ => l10n.lobbyEmojiDifficultyHard,
    };

class LobbyPage extends ConsumerWidget {
  const LobbyPage({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(lobbyControllerProvider);
    return RoomRouteSync(
      roomId: roomId,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.lobbyTitle),
          actions: [
            if (state is! LobbyNoRoom)
              TextButton(
                onPressed: () => confirmLeaveRoom(context, ref),
                child: Text(l10n.lobbyLeave),
              ),
            const SizedBox(width: Spacing.xs),
          ],
        ),
        body: SafeArea(
          top: false,
          child: switch (state) {
            LobbyNoRoom() => const _NoRoom(),
            LobbyConnecting(:final roomCode) => _Connecting(roomCode: roomCode),
            LobbyLoaded(:final view) => _LobbyBody(view: view),
          },
        ),
        bottomNavigationBar: switch (state) {
          LobbyLoaded(:final view) => _LobbyActions(view: view),
          _ => null,
        },
      ),
    );
  }
}

Future<void> confirmLeaveRoom(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.lobbyLeaveConfirmTitle),
      content: Text(l10n.lobbyLeaveConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.lobbyLeave),
        ),
      ],
    ),
  );
  if (leave != true || !context.mounted) return;
  await ref.read(activeRoomProvider.notifier).leave();
  if (context.mounted) context.go(Routes.home);
}

class _NoRoom extends StatelessWidget {
  const _NoRoom();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.lobbyNoRoom,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: Spacing.md),
        FilledButton(
          onPressed: () => context.go(Routes.home),
          child: Text(context.l10n.lobbyBackHome),
        ),
      ],
    ),
  );
}

class _Connecting extends StatelessWidget {
  const _Connecting({required this.roomCode});

  final String? roomCode;

  @override
  Widget build(BuildContext context) {
    final code = roomCode;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (code != null) _CodeText(code: code),
          const SizedBox(height: Spacing.lg),
          const CircularProgressIndicator(),
          const SizedBox(height: Spacing.md),
          Text(context.l10n.lobbyConnecting),
        ],
      ),
    );
  }
}

class _LobbyBody extends ConsumerWidget {
  const _LobbyBody({required this.view});

  final LobbyView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.xs,
        Spacing.lg,
        Spacing.xl,
      ),
      children: [
        if (view.reconnecting)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: _Banner(text: l10n.lobbyReconnecting),
          ),
        _InviteCard(view: view),
        if (view.isDjHost) ...[
          const SizedBox(height: Spacing.md),
          Text(
            l10n.lobbyDjHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: Spacing.lg),
        _SettingsCard(view: view),
        if (view.showsDj) ...[
          const SizedBox(height: Spacing.md),
          _CanDjTile(view: view),
        ],
        if (view.collectsPools) ...[
          const SizedBox(height: Spacing.lg),
          _MySongsCard(view: view),
        ],
        const SizedBox(height: Spacing.lg),
        Text(
          l10n.lobbyPlayersTitle(view.players.length),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: Spacing.xs),
        for (final player in view.players)
          _PlayerTile(
            player: player,
            viewerIsHost: view.isHost,
            showsDj: view.showsDj,
          ),
        if (view.contributorsNeeded > 0) ...[
          const SizedBox(height: Spacing.sm),
          Text(
            l10n.lobbyNeedContributors(view.contributorsNeeded),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// «Добавить мои песни»: this player's pool for the room, sent only after
/// the «Что увидят друзья» consent (design doc S1.9).
class _MySongsCard extends ConsumerWidget {
  const _MySongsCard({required this.view});

  final LobbyView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final count = view.myPoolTrackCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.homeMySongs, style: theme.textTheme.titleMedium),
            if (count > 0) ...[
              const SizedBox(height: Spacing.xxs),
              Text(l10n.lobbyPoolTrackCount(count)),
            ],
            const SizedBox(height: Spacing.sm),
            FilledButton.tonalIcon(
              key: const ValueKey('lobby-add-my-songs'),
              onPressed: () => _addMySongs(context, ref),
              icon: const Icon(Icons.queue_music_rounded),
              label: Text(
                count > 0 ? l10n.lobbyUpdateMySongs : l10n.lobbyAddMySongs,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _addMySongs(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final controller = ref.read(lobbyControllerProvider.notifier);
    void snack(String text, {SnackBarAction? action}) =>
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(text), action: action));

    final draft = await controller.preparePool();
    if (!context.mounted) return;
    switch (draft) {
      case PoolUnavailable():
        snack(l10n.lobbyPoolFailed);
      case PoolNeedsPicks(:final minimum):
        snack(
          l10n.lobbyPoolNeedPicks(minimum),
          action: SnackBarAction(
            label: l10n.lobbyOpenMySongs,
            onPressed: () => context.push(Routes.mySongs),
          ),
        );
      case PoolReady(:final picks):
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => _PoolConsentDialog(picks: picks),
        );
        if (confirmed != true || !context.mounted) return;
        final sent = await controller.submitPool(draft);
        if (!context.mounted) return;
        snack(sent ? l10n.lobbyPoolSent : l10n.lobbyPoolFailed);
    }
  }
}

/// «Что увидят друзья»: exactly the list that may be revealed as this
/// player's, and the consent «Эти песни будут показаны комнате как ваши».
class _PoolConsentDialog extends StatelessWidget {
  const _PoolConsentDialog({required this.picks});

  final List<CatalogPick> picks;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.mySongsPreviewTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(l10n.mySongsPreviewBody),
            const SizedBox(height: Spacing.sm),
            for (final pick in picks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xxs),
                child: Text(
                  '${pick.title} — ${pick.artists.join(', ')}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: Spacing.sm),
            Text(l10n.lobbyPoolConsentBody, style: theme.textTheme.titleSmall),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('pool-consent-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.lobbyPoolConsentConfirm),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeText extends StatelessWidget {
  const _CodeText({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final party = PartyColors.of(context);
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          LinearGradient(colors: party.gradient).createShader(bounds),
      child: Text(
        code,
        style: Theme.of(context).textTheme.displaySmall
            ?.copyWith(letterSpacing: 8, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _InviteCard extends ConsumerWidget {
  const _InviteCard({required this.view});

  final LobbyView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final link = view.joinLink;
    final qr = view.qrLink;
    final controller = ref.read(lobbyControllerProvider.notifier);
    final shareText = link == null
        ? l10n.lobbyShareTextNoLink(view.roomCode)
        : l10n.lobbyShareText(view.roomCode, link.toString());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          children: [
            Text(l10n.lobbyCodeLabel, style: theme.textTheme.labelLarge),
            const SizedBox(height: Spacing.xs),
            Semantics(
              label: l10n.lobbyCodeLabel,
              child: _CodeText(code: view.roomCode),
            ),
            if (qr != null) ...[
              const SizedBox(height: Spacing.md),
              QrCodeView(
                data: qr.toString(),
                semanticLabel: l10n.lobbyQrSemantics(view.roomCode),
              ),
            ],
            const SizedBox(height: Spacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Spacing.sm,
              runSpacing: Spacing.xs,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => controller.share(shareText),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(l10n.lobbyShare),
                ),
                if (link != null)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: link.toString()),
                      );
                      controller.linkCopied();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(content: Text(l10n.lobbyLinkCopied)),
                        );
                    },
                    icon: const Icon(Icons.link_rounded),
                    label: Text(l10n.lobbyCopyLink),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard({required this.view});

  final LobbyView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final controller = ref.read(lobbyControllerProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.lobbySettingsTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: Spacing.md),
            // Chips wrap on narrow phones; three segments would not fit.
            Wrap(
              spacing: Spacing.xs,
              runSpacing: Spacing.xs,
              children: [
                for (final mode in GameMode.values)
                  ChoiceChip(
                    key: ValueKey('lobby-mode-${mode.wire}'),
                    label: Text(gameModeLabel(l10n, mode)),
                    selected: view.mode == mode,
                    onSelected: view.isHost
                        ? (_) => controller.setMode(mode)
                        : null,
                  ),
              ],
            ),
            if (view.isEmojiQuiz) ...[
              const SizedBox(height: Spacing.xs),
              Text(
                l10n.lobbyEmojiHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text(l10n.lobbyEmojiMarkets, style: theme.textTheme.labelLarge),
              const SizedBox(height: Spacing.xs),
              Wrap(
                spacing: Spacing.xs,
                runSpacing: Spacing.xs,
                children: [
                  for (final market in EmojiMarket.values)
                    FilterChip(
                      key: ValueKey('lobby-emoji-market-${market.wire}'),
                      label: Text(emojiMarketLabel(l10n, market)),
                      selected: view.emojiMarkets.contains(market),
                      onSelected: view.isHost
                          ? (_) => controller.toggleEmojiMarket(market)
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              Text(
                l10n.lobbyEmojiDifficulty,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: Spacing.xs),
              Wrap(
                spacing: Spacing.xs,
                runSpacing: Spacing.xs,
                children: [
                  for (
                    var difficulty = EmojiDifficulty.min;
                    difficulty <= EmojiDifficulty.max;
                    difficulty++
                  )
                    ChoiceChip(
                      key: ValueKey('lobby-emoji-difficulty-$difficulty'),
                      label: Text(emojiDifficultyLabel(l10n, difficulty)),
                      selected: view.emojiMaxDifficulty == difficulty,
                      onSelected: view.isHost
                          ? (_) => controller.setEmojiMaxDifficulty(difficulty)
                          : null,
                    ),
                ],
              ),
            ],
            const SizedBox(height: Spacing.md),
            Text(l10n.lobbyRoundsLabel, style: theme.textTheme.labelLarge),
            const SizedBox(height: Spacing.xs),
            Wrap(
              spacing: Spacing.xs,
              runSpacing: Spacing.xs,
              children: [
                for (final choice in view.roundChoices)
                  ChoiceChip(
                    label: Text('${choice.rounds}'),
                    avatar: choice.locked
                        ? const Icon(Icons.lock_rounded, size: 16)
                        : null,
                    tooltip: choice.locked
                        ? l10n.lobbyRoundsLocked(choice.rounds)
                        : null,
                    selected: choice.rounds == view.roundsTotal,
                    onSelected: view.isHost
                        ? (_) {
                            if (!controller.setRounds(choice.rounds)) {
                              context.push(
                                Routes.paywallFor(
                                  PaywallPlacement.lobbyRounds.wireName,
                                ),
                              );
                            }
                          }
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// «Могу включать музыку» (BYOP): opt in to the DJ role, `lobby.set_can_dj`.
class _CanDjTile extends ConsumerWidget {
  const _CanDjTile({required this.view});

  final LobbyView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Card(
      child: SwitchListTile(
        key: const ValueKey('lobby-can-dj'),
        value: view.meCanDj,
        onChanged: ref.read(lobbyControllerProvider.notifier).setCanDj,
        secondary: const Icon(Icons.speaker_rounded),
        title: Text(l10n.lobbyCanDj),
        subtitle: Text(l10n.lobbyCanDjHint),
      ),
    );
  }
}

class _PlayerTile extends ConsumerWidget {
  const _PlayerTile({
    required this.player,
    required this.viewerIsHost,
    this.showsDj = false,
  });

  final LobbyPlayer player;
  final bool viewerIsHost;

  /// BYOP: players who opted in to the DJ role get a DJ badge.
  final bool showsDj;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final away = player.connection != PlayerConnection.connected;
    final badges = [
      if (player.isHost) l10n.lobbyHostBadge,
      if (player.isMe) l10n.lobbyYouBadge,
      if (showsDj && player.canDj) l10n.lobbyDjBadge,
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          player.name.isEmpty ? '?' : player.name.characters.first,
          style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
        ),
      ),
      title: Text(player.name),
      subtitle: Text(
        [
          ...badges,
          if (player.poolTrackCount > 0)
            l10n.lobbyPoolTrackCount(player.poolTrackCount),
          if (away)
            l10n.lobbyAway
          else if (!player.isHost)
            player.ready ? l10n.lobbyReady : l10n.lobbyNotReady,
        ].join(' · '),
      ),
      trailing: player.isMe
          ? null
          : PopupMenuButton<_PlayerAction>(
              onSelected: (action) => _onAction(context, ref, action),
              itemBuilder: (context) => [
                if (viewerIsHost && !player.isHost)
                  PopupMenuItem(
                    value: _PlayerAction.kick,
                    child: Text(l10n.lobbyKick),
                  ),
                PopupMenuItem(
                  value: _PlayerAction.report,
                  child: Text(l10n.lobbyReport),
                ),
              ],
            ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _PlayerAction action,
  ) async {
    final controller = ref.read(lobbyControllerProvider.notifier);
    switch (action) {
      case _PlayerAction.kick:
        controller.kick(player.playerId);
      case _PlayerAction.report:
        final l10n = context.l10n;
        final reason = await showDialog<ReportReason>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(l10n.lobbyReportTitle),
            children: [
              for (final reason in ReportReason.values)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(reason),
                  child: Text(reportReasonLabel(l10n, reason)),
                ),
            ],
          ),
        );
        if (reason == null) return;
        final sent = await controller.report(player.playerId, reason);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                sent ? l10n.lobbyReportSent : l10n.lobbyReportFailed,
              ),
            ),
          );
    }
  }
}

enum _PlayerAction { kick, report }

String reportReasonLabel(AppLocalizations l10n, ReportReason reason) =>
    switch (reason) {
      ReportReason.offensiveName => l10n.reportReasonName,
      ReportReason.cheating => l10n.reportReasonCheating,
      ReportReason.harassment => l10n.reportReasonHarassment,
      ReportReason.spam => l10n.reportReasonSpam,
      ReportReason.other => l10n.reportReasonOther,
    };

class _LobbyActions extends ConsumerWidget {
  const _LobbyActions({required this.view});

  final LobbyView view;

  /// What still blocks the start; missing contributors are already shown
  /// under the player list.
  static String? _blockerText(AppLocalizations l10n, StartBlocker? blocker) =>
      switch (blocker) {
        NeedMorePlayers(:final minimum) => l10n.lobbyNeedPlayers(minimum),
        PoolTooSmall(:final name, :final minimum) => l10n.lobbyPoolTooSmall(
          name,
          minimum,
        ),
        NeedAnyPool() => l10n.lobbyNeedAnyPool,
        NeedContributors() || null => null,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final controller = ref.read(lobbyControllerProvider.notifier);
    final blocker = view.startBlocker;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.xs,
          Spacing.lg,
          Spacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (view.isHost) ...[
              if (_blockerText(l10n, blocker) case final text?)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xs),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: view.canStart ? controller.startGame : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.lobbyStart),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.xs),
                child: Text(
                  l10n.lobbyWaitingForHost,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              view.meReady
                  ? FilledButton.icon(
                      onPressed: controller.toggleReady,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(l10n.lobbyReady),
                    )
                  : FilledButton.tonal(
                      onPressed: controller.toggleReady,
                      child: Text(l10n.lobbyImReady),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}
