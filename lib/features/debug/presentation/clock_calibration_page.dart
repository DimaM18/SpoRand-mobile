import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/core/clock/clock_calibration.dart';
import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/clock/input_timestamps.dart';
import 'package:sporand/core/l10n/l10n.dart';

/// Device timing calibration (brief §5 "Device test", §9): records, per tap,
/// the pointer timestamp, the next frame's timestamp and
/// `InputClockApi.nowMicros()`, all converted through the process anchor, and
/// checks that they share one clock base.
/// Reachable from Settings in non-production builds.
class ClockCalibrationPage extends ConsumerStatefulWidget {
  const ClockCalibrationPage({super.key});

  @override
  ConsumerState<ClockCalibrationPage> createState() =>
      _ClockCalibrationPageState();
}

class _ClockCalibrationPageState extends ConsumerState<ClockCalibrationPage> {
  late final InputClock _clock = ref.read(inputClockProvider);
  late final ClockCalibrationRecorder _recorder = ClockCalibrationRecorder(
    _clock,
  );

  void _onPointerDown(PointerDownEvent event) {
    // Every source goes through the same process anchor as in a game.
    final pointerUs = tapMonoUsFromPointer(_clock, event);
    // Measure the frame clock exactly like unlock_mono_us: the timestamp of
    // the next frame, read in its post-frame callback.
    SchedulerBinding.instance
      ..addPostFrameCallback((_) async {
        await _recorder.record(
          pointerUs: pointerUs,
          frameUs: currentFrameMonoUs(_clock),
        );
        if (mounted) setState(() {});
      })
      ..scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final summary = _recorder.summarize();
    final samples = _recorder.samples.reversed.take(12).toList();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.debugClockTitle)),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          Text(l10n.debugClockHint),
          const SizedBox(height: Spacing.md),
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPointerDown,
            child: Container(
              height: 180,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(Radii.lg),
              ),
              child: Text(
                l10n.debugClockTapArea,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          if (summary != null)
            Text(
              summary.passed
                  ? l10n.debugClockPassed(summary.samples)
                  : l10n.debugClockFailed(summary.samples),
              style: theme.textTheme.titleMedium?.copyWith(
                color: summary.passed
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.error,
              ),
            ),
          for (final s in samples)
            Text(
              'pointer ${(s.pointerLagUs / 1000).toStringAsFixed(1)} ms · '
              'frame ${(s.frameLagUs / 1000).toStringAsFixed(1)} ms',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.sm,
            children: [
              FilledButton.tonal(
                onPressed: summary == null
                    ? null
                    : () => Clipboard.setData(
                        ClipboardData(text: _recorder.report()),
                      ),
                child: Text(l10n.debugClockCopy),
              ),
              OutlinedButton(
                onPressed: () => setState(_recorder.clear),
                child: Text(l10n.debugClockClear),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
