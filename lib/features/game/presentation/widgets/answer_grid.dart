import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/clock/input_timestamps.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';

/// The answer buttons of a round, in the server's per-player order.
///
/// Timing (brief §5): the post-frame callback of the first frame that shows
/// enabled buttons reports `unlock_mono_us`; each button is a [Listener]
/// whose `onPointerDown` hands the OS touch time to the controller. The
/// first pointer down commits; the controller ignores every later one.
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
    final enabled = state.buttonsEnabled;
    if (enabled && _unlockReportedFor != round.roundId) {
      _unlockReportedFor = round.roundId;
      final roundId = round.roundId;
      // This build belongs to the first frame with enabled buttons; the
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
    final chosen = switch (state.phase) {
      RoundAnswered(:final optionId) => optionId,
      _ => null,
    };
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
              enabled: enabled,
              selected: chosen == option.optionId,
              dimmed: chosen != null && chosen != option.optionId,
              clock: clock,
              onCommit: (tapMonoUs) => _commit(option.optionId, tapMonoUs),
            ),
          ),
      ],
    );
  }
}

/// One answer. Not a Material button on purpose: `onTap` fires when the
/// finger lifts and `onTapDown` carries no timestamp (and can be delayed by
/// `kPressTimeout`), so only `onPointerDown` gives the touch time.
class AnswerButton extends StatelessWidget {
  const AnswerButton({
    super.key,
    required this.option,
    required this.index,
    required this.enabled,
    required this.selected,
    required this.dimmed,
    required this.clock,
    required this.onCommit,
  });

  static const _accents = [
    BrandColors.violet,
    BrandColors.magenta,
    BrandColors.cyan,
    BrandColors.amber,
  ];

  final RoundOption option;
  final int index;
  final bool enabled;
  final bool selected;
  final bool dimmed;

  /// Converts the OS touch time to `tap_mono_us` (process anchor).
  final InputClock clock;

  /// Returns true when the tap committed the answer.
  final bool Function(int? tapMonoUs) onCommit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accents[index % _accents.length];
    final active = enabled || selected;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: option.label,
      excludeSemantics: true,
      // Screen readers activate without a touch event; the controller then
      // stamps the tap with the input clock.
      onTap: enabled ? () => onCommit(null) : null,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: enabled
            ? (event) => onCommit(tapMonoUsFromPointer(clock, event))
            : null,
        child: AnimatedOpacity(
          duration: Motion.fast,
          opacity: dimmed ? 0.35 : (active ? 1 : 0.55),
          child: AnimatedContainer(
            duration: Motion.fast,
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? accent
                  : Color.alphaBlend(
                      accent.withValues(alpha: 0.16),
                      theme.colorScheme.surfaceContainer,
                    ),
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(
                color: accent.withValues(alpha: active ? 0.9 : 0.4),
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: selected ? Colors.white : accent,
                  child: Text(
                    String.fromCharCode(0x41 + index),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: selected ? accent : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Text(
                    option.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: selected ? Colors.white : null,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
