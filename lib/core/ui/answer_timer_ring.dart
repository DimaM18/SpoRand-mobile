import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/theme/tokens.dart';

/// A 56 dp countdown ring for the answer window (design system §6.7).
///
/// **Visual only.** It runs [window] on a vsync [AnimationController] from
/// the moment [running] turns true (start it from the post-frame unlock
/// callback); it never reads `DateTime.now()` or a `Stopwatch`, never feeds
/// a wire value and never gates input. The server's `round.time_up`
/// decides. Give it a new key per round to restart it.
///
/// The last [urgentBelow] turns the arc `timerUrgent` and shows the number.
/// Screen readers get «Осталось {seconds} с», announced at 10 s and 5 s
/// only. Under reduce-motion the arc steps once per second on a timer (no
/// frame loop). Never on the DJ player screen.
class AnswerTimerRing extends StatefulWidget {
  const AnswerTimerRing({
    super.key,
    required this.window,
    required this.running,
    this.size = 56,
    this.urgentBelow = const Duration(seconds: 5),
  });

  final Duration window;
  final bool running;
  final double size;
  final Duration urgentBelow;

  @override
  State<AnswerTimerRing> createState() => _AnswerTimerRingState();
}

class _AnswerTimerRingState extends State<AnswerTimerRing>
    with SingleTickerProviderStateMixin {
  static const _announceAt = {10, 5};

  // `preserve`: the ring measures real time. With the default behaviour,
  // Android's «Remove animations» scales the duration to 5 % and the ring
  // would say «0» while answers are still open.
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: _safeWindow,
    animationBehavior: AnimationBehavior.preserve,
  )..addListener(_onTick);

  late final ValueNotifier<int> _seconds = ValueNotifier(_totalSecondsLeft);

  /// Reduce-motion steps once a second on a one-shot [Timer] (no frame
  /// loop at all); otherwise the arc sweeps on [_progress].
  Timer? _step;
  int _leftMs = 0;
  bool _started = false;

  Duration get _safeWindow => widget.window > Duration.zero
      ? widget.window
      : const Duration(milliseconds: 1);

  int get _totalSecondsLeft => (_safeWindow.inMilliseconds / 1000).ceil();

  void _onTick() {
    final leftMs = _safeWindow.inMilliseconds * (1 - _progress.value);
    _show((leftMs / 1000).ceil());
  }

  void _show(int seconds) {
    if (seconds == _seconds.value) return;
    _seconds.value = seconds;
    if (_announceAt.contains(seconds) && mounted) {
      final media = MediaQuery.maybeOf(context);
      if (media?.accessibleNavigation ?? false) {
        unawaited(
          SemanticsService.sendAnnouncement(
            View.of(context),
            context.l10n.gameTimeLeftSemantics(seconds),
            Directionality.of(context),
          ),
        );
      }
    }
  }

  void _start() {
    _stop();
    _started = true;
    if (Motion.reduced(context)) {
      _leftMs = _safeWindow.inMilliseconds;
      _show(_totalSecondsLeft);
      _scheduleStep();
    } else {
      unawaited(_progress.forward(from: 0));
    }
  }

  void _scheduleStep() {
    if (_leftMs <= 0) return;
    final stepMs = _leftMs % 1000 == 0 ? 1000 : _leftMs % 1000;
    _step = Timer(Duration(milliseconds: stepMs), () {
      if (!mounted) return;
      _leftMs -= stepMs;
      _show((_leftMs / 1000).ceil());
      _scheduleStep();
    });
  }

  void _stop() {
    _step?.cancel();
    _step = null;
    _progress.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The first start needs the MediaQuery (reduce-motion), so not in
    // initState.
    if (widget.running && !_started) _start();
  }

  @override
  void didUpdateWidget(AnswerTimerRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.window != widget.window) {
      _progress.duration = _safeWindow;
    }
    if (widget.running && !oldWidget.running) {
      _start();
    } else if (!widget.running && oldWidget.running) {
      _stop();
    }
  }

  @override
  void dispose() {
    _step?.cancel();
    _progress.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final party = PartyColors.of(context);
    final game = GameColors.of(context);
    final reduce = Motion.reduced(context);
    final totalSeconds = math.max(
      1,
      (_safeWindow.inMilliseconds / 1000).ceil(),
    );
    final urgentSeconds = (widget.urgentBelow.inMilliseconds / 1000).ceil();
    return ValueListenableBuilder<int>(
      valueListenable: _seconds,
      builder: (context, seconds, _) {
        final urgent = seconds <= urgentSeconds;
        final arc = urgent ? game.timerUrgent : theme.colorScheme.primary;
        return Semantics(
          label: context.l10n.gameTimeLeftSemantics(seconds),
          excludeSemantics: true,
          child: RepaintBoundary(
            child: SizedBox.square(
              dimension: widget.size,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: _progress,
                  stepped: reduce,
                  seconds: seconds,
                  totalSeconds: totalSeconds,
                  track: party.ringTrack,
                  arc: arc,
                ),
                child: urgent
                    ? Center(
                        child: MediaQuery.withNoTextScaling(
                          child: Text(
                            '$seconds',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: arc,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.stepped,
    required this.seconds,
    required this.totalSeconds,
    required this.track,
    required this.arc,
  }) : super(repaint: stepped ? null : progress);

  final Animation<double> progress;
  final bool stepped;
  final int seconds;
  final int totalSeconds;
  final Color track;
  final Color arc;

  static const _stroke = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final remaining = stepped
        ? (seconds / totalSeconds).clamp(0.0, 1.0)
        : 1 - progress.value;
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = track,
    );
    if (remaining <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * remaining,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.stepped != stepped ||
      old.seconds != seconds ||
      old.totalSeconds != totalSeconds ||
      old.track != track ||
      old.arc != arc ||
      old.progress != progress;
}
