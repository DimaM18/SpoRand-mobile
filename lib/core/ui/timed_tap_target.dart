import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/clock/input_timestamps.dart';

/// Builds the look of a [TimedTapTarget] for the current pressed state.
typedef TimedTapBuilder = Widget Function(BuildContext context, bool pressed);

/// The only input path for timed taps: answers and the DJ's
/// «Музыка играет!» (CLAUDE.md hard rule 6).
///
/// - A [Listener] whose `onPointerDown` hands the OS touch time, converted
///   by [tapMonoUsFromPointer] through [clock], to [onCommit]. `onTap`
///   fires only when the finger lifts and `onTapDown` carries no timestamp
///   (and can be delayed by `kPressTimeout`), so this is never a
///   `GestureDetector`, `InkWell` or Material button.
/// - A [Semantics] `onTap` for screen readers: an activation without a
///   touch commits `null`, and the controller stamps it with the input
///   clock.
/// - `onPointerUp`/`onPointerCancel` only clear the local pressed look.
///
/// The commit runs before any visual update. [enabled] switches instantly:
/// the target is never wrapped in `IgnorePointer`/`AbsorbPointer` and the
/// builder must not animate the enabled change, so it looks tappable on the
/// very frame reported as the unlock.
class TimedTapTarget extends StatefulWidget {
  const TimedTapTarget({
    super.key,
    required this.enabled,
    required this.clock,
    required this.onCommit,
    required this.builder,
    this.semanticsLabel,
    this.semanticsHint,
    this.semanticsValue,
    this.selected,
  });

  final bool enabled;

  /// Converts the OS touch time to `*_mono_us` (process anchor).
  final InputClock clock;

  /// Receives the tap time in mono µs, or `null` for a screen-reader
  /// activation. A `bool`-returning callback (committed or not) fits too.
  final void Function(int? tapMonoUs) onCommit;

  final TimedTapBuilder builder;
  final String? semanticsLabel;
  final String? semanticsHint;

  /// The target's state in words (e.g. «Твой ответ»): a value is always
  /// read, a hint may be skipped.
  final String? semanticsValue;
  final bool? selected;

  @override
  State<TimedTapTarget> createState() => _TimedTapTargetState();
}

class _TimedTapTargetState extends State<TimedTapTarget> {
  bool _pressed = false;

  @override
  void didUpdateWidget(TimedTapTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _pressed = false;
  }

  void _down(PointerDownEvent event) {
    if (!widget.enabled) return;
    widget.onCommit(tapMonoUsFromPointer(widget.clock, event));
    if (mounted && !_pressed) setState(() => _pressed = true);
  }

  void _release(PointerEvent _) {
    if (_pressed && mounted) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticsLabel,
      hint: widget.semanticsHint,
      value: widget.semanticsValue,
      excludeSemantics: widget.semanticsLabel != null,
      onTap: enabled ? () => widget.onCommit(null) : null,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: enabled ? _down : null,
        onPointerUp: _release,
        onPointerCancel: _release,
        child: widget.builder(context, enabled && _pressed),
      ),
    );
  }
}
