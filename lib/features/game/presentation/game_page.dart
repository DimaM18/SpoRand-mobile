import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';
import 'package:sporand/features/game/presentation/widgets/end_of_game_views.dart';
import 'package:sporand/features/game/presentation/widgets/reveal_view.dart';
import 'package:sporand/features/game/presentation/widgets/round_views.dart';
import 'package:sporand/features/lobby/presentation/lobby_page.dart';
import 'package:sporand/features/lobby/presentation/room_route_sync.dart';

/// The round screen: renders [GameUiState]; all logic lives in
/// [GameController].
///
/// Screens cross-fade, except to or from the DJ's YouTube player screen:
/// the player is never faded (it is always at full opacity), so that switch
/// is instant and the old screen is dropped at once.
class GamePage extends ConsumerStatefulWidget {
  const GamePage({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<GamePage> createState() => _GamePageState();
}

class _GamePageState extends ConsumerState<GamePage> {
  String? _screenKey;
  bool _screenIsPlayer = false;
  bool _instant = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    final key = _keyFor(state);
    final playerScreen = isPlayerRound(state);
    if (key != _screenKey) {
      _instant = playerScreen || _screenIsPlayer;
      _screenKey = key;
      _screenIsPlayer = playerScreen;
    }
    final instant = _instant;
    final screen = KeyedSubtree(
      key: ValueKey(key),
      child: _body(context, state),
    );
    return RoomRouteSync(
      roomId: widget.roomId,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          // The round screens stay still (the DJ's player screen above all):
          // no scrolled-under colour change.
          notificationPredicate: (_) => false,
          actions: [
            _LeaveAction(
              inline: state is GameRoundState && state.showsVideoPlayer,
            ),
            const SizedBox(width: Spacing.xs),
          ],
        ),
        body: SafeArea(
          top: false,
          // To or from the player screen there is no switcher at all: no
          // fade, no stacked old screen, no ticker left running.
          child: instant
              ? screen
              : AnimatedSwitcher(
                  duration: Motion.reduced(context)
                      ? Duration.zero
                      : Motion.medium,
                  child: screen,
                ),
        ),
      ),
    );
  }

  /// Phase changes inside a round keep the same key (no cross-fade), so the
  /// answers do not move under the player's finger.
  static String _keyFor(GameUiState state) => switch (state) {
    GameRoundState(:final round) => 'round-${round.roundId}',
    GameRevealState(:final reveal) => 'reveal-${reveal.round.roundId}',
    GameBonusState(:final bonusId) => 'bonus-$bonusId',
    _ => state.runtimeType.toString(),
  };

  static Widget _body(BuildContext context, GameUiState state) {
    final l10n = context.l10n;
    return switch (state) {
      GameIdle() ||
      GameFinishedState() => StatusScreen(title: l10n.gameWaiting, busy: true),
      GameStartingState() => StartingScreen(state: state),
      GameRoundState() => RoundScreen(state: state),
      GameRevealState(:final reveal) => RevealScreen(reveal: reveal),
      GameVoidedState(:final reason) => StatusScreen(
        title: l10n.gameVoided,
        subtitle: voidReasonText(l10n, reason),
        icon: Icons.replay_rounded,
      ),
      GamePausedState() => StatusScreen(
        title: l10n.gamePaused,
        subtitle: l10n.gamePausedHint,
        busy: true,
      ),
      GameBonusState() => BonusScreen(state: state),
      GameAdBreakState() => AdBreakScreen(state: state),
    };
  }
}

/// «Выйти». With the YouTube player on screen ([inline]) it never opens a
/// dialog over the player: the first press turns it into «Остаться» +
/// «Выйти из игры?» in the app bar; the second press leaves. The confirm
/// has no time limit (WCAG 2.2.1): it stays until «Остаться», leaving, or
/// the end of the player screen, and focus moves to «Остаться». Elsewhere
/// it asks with the usual dialog.
class _LeaveAction extends ConsumerStatefulWidget {
  const _LeaveAction({required this.inline});

  final bool inline;

  /// The confirm labels grow with the text scale up to this factor; past
  /// it only the label text shrinks to fit the app bar, never the targets.
  static const maxLabelScale = 1.3;

  @override
  ConsumerState<_LeaveAction> createState() => _LeaveActionState();
}

class _LeaveActionState extends ConsumerState<_LeaveAction> {
  final FocusNode _stayFocus = FocusNode(debugLabel: 'game-leave-cancel');
  bool _confirming = false;

  @override
  void didUpdateWidget(_LeaveAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.inline) _confirming = false;
  }

  @override
  void dispose() {
    _stayFocus.dispose();
    super.dispose();
  }

  void _onLeave() {
    if (!widget.inline) {
      unawaited(confirmLeaveRoom(context, ref));
      return;
    }
    setState(() => _confirming = true);
    // The pressed «Выйти» is gone: put keyboard and screen-reader focus on
    // the new, safe choice.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_confirming) return;
      _stayFocus.requestFocus();
      _stayFocus.context?.findRenderObject()?.sendSemanticsEvent(
        const FocusSemanticEvent(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    if (!_confirming) {
      return TextButton.icon(
        key: const ValueKey('game-leave'),
        onPressed: _onLeave,
        icon: const Icon(Icons.logout_rounded),
        label: Text(l10n.lobbyLeave),
      );
    }
    // Never a FittedBox around the buttons (it would shrink the 48 dp
    // targets too): the targets keep their size and only the label text
    // scales down when the app bar is too small for it.
    Widget label(String text) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, softWrap: false),
    );
    const target = Size(TapTargets.min, TapTargets.min);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - Spacing.md,
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: _LeaveAction.maxLabelScale,
        child: Semantics(
          liveRegion: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                key: const ValueKey('game-leave-cancel'),
                focusNode: _stayFocus,
                style: TextButton.styleFrom(minimumSize: target),
                onPressed: () => setState(() => _confirming = false),
                child: label(l10n.gameLeaveInlineCancel),
              ),
              const SizedBox(width: Spacing.xs),
              Flexible(
                child: OutlinedButton(
                  key: const ValueKey('game-leave-confirm'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error, width: 1.5),
                    minimumSize: target,
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  ),
                  onPressed: () {
                    setState(() => _confirming = false);
                    unawaited(leaveRoom(context, ref));
                  },
                  child: label(l10n.gameLeaveInlineConfirm),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
