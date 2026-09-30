import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/clock/input_timestamps.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/ui.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';

/// The answer tiles of a round, in the server's per-player order.
///
/// Timing (`docs/DEVELOPMENT.md`, timing): the post-frame callback of the
/// first frame that shows enabled tiles reports `unlock_mono_us`; each tile
/// is a [TimedTapTarget] (`Listener.onPointerDown`) that hands the OS touch
/// time to the controller. The first pointer down commits; the controller
/// ignores every later one. Tiles switch to enabled instantly (no fade), so
/// they look tappable on the very frame reported as the unlock.
class AnswerGrid extends ConsumerStatefulWidget {
  const AnswerGrid({super.key, required this.state});

  final GameRoundState state;

  @override
  ConsumerState<AnswerGrid> createState() => _AnswerGridState();
}

class _AnswerGridState extends ConsumerState<AnswerGrid> {
  String? _unlockReportedFor;

  bool _commit(String optionId, int? tapMonoUs) {
    final committed = ref
        .read(gameControllerProvider.notifier)
        .tap(
          roundId: widget.state.round.roundId,
          optionId: optionId,
          tapMonoUs: tapMonoUs,
        );
    if (committed) unawaited(HapticFeedback.mediumImpact());
    return committed;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final round = state.round;
    if (state.buttonsEnabled && _unlockReportedFor != round.roundId) {
      _unlockReportedFor = round.roundId;
      final roundId = round.roundId;
      // This build belongs to the first frame with enabled tiles; the
      // callback runs once that frame is built, before it is shown, while
      // currentSystemFrameTimeStamp still refers to it.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(gameControllerProvider.notifier)
            .onAnswerButtonsShown(
              roundId,
              currentFrameMonoUs(ref.read(inputClockProvider)),
            );
      });
    }
    final clock = ref.read(inputClockProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, option) in round.options.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: AnswerButton(
              key: ValueKey('answer-${option.optionId}'),
              option: option,
              index: index,
              mode: AnswerButton.modeFor(state.phase, option.optionId),
              clock: clock,
              onCommit: (tapMonoUs) => _commit(option.optionId, tapMonoUs),
            ),
          ),
      ],
    );
  }
}

/// One answer of a round: the design system's [AnswerTile] (shape marker,
/// letter, text, fixed state slot) on a [TimedTapTarget].
///
/// Never a Material button, `InkWell` or `GestureDetector`: `onTap` fires
/// when the finger lifts and `onTapDown` carries no timestamp (and can be
/// delayed by `kPressTimeout`), so only `onPointerDown` gives the touch
/// time. A screen-reader activation commits `null` and the controller
/// stamps it with the input clock.
class AnswerButton extends StatelessWidget {
  const AnswerButton({
    super.key,
    required this.option,
    required this.index,
    required this.mode,
    required this.clock,
    required this.onCommit,
  });

  final RoundOption option;

  /// The slot in the server's order: colour, shape and letter.
  final int index;
  final AnswerTileMode mode;

  /// Converts the OS touch time to `tap_mono_us` (process anchor).
  final InputClock clock;

  /// Returns true when the tap committed the answer.
  final bool Function(int? tapMonoUs) onCommit;

  /// Only [AnswerTileMode.open] takes taps.
  bool get enabled => mode == AnswerTileMode.open;

  /// How option [optionId] looks in [phase]: readable but locked before the
  /// unlock, open while the window runs, then the pick and the rest (never
  /// dimmed by opacity).
  static AnswerTileMode modeFor(RoundPhase phase, String optionId) =>
      switch (phase) {
        RoundOpen() => AnswerTileMode.open,
        RoundAnswered(optionId: final chosen) =>
          chosen == optionId ? AnswerTileMode.picked : AnswerTileMode.faded,
        RoundTimeUp() => AnswerTileMode.faded,
        _ => AnswerTileMode.locked,
      };

  @override
  Widget build(BuildContext context) => AnswerTile(
    label: option.label,
    index: index,
    mode: mode,
    clock: clock,
    onCommit: onCommit,
  );
}
