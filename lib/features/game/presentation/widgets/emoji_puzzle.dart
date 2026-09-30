import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/protocol/emoji_text.dart';

/// The emoji line of an emoji_quiz round [новое имя — согласовать].
///
/// Hidden behind «?» tiles until [revealed] (the round opens at the same
/// moment for everyone, so nobody can read the puzzle early), then each
/// emoji pops in with a short stagger. With reduced motion (or [animate]
/// false) the emoji simply appear.
class EmojiPuzzle extends StatefulWidget {
  const EmojiPuzzle({
    super.key,
    required this.emoji,
    required this.revealed,
    this.animate = true,
    this.size = 56,
  });

  final String emoji;
  final bool revealed;
  final bool animate;
  final double size;

  /// The pop of one emoji; each next one starts [stagger] later.
  static const pop = Duration(milliseconds: 320);
  static const stagger = Duration(milliseconds: 70);

  @override
  State<EmojiPuzzle> createState() => _EmojiPuzzleState();
}

class _EmojiPuzzleState extends State<EmojiPuzzle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  List<String> get _emoji => emojiGraphemes(widget.emoji) ?? [widget.emoji];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.revealed && !_controller.isAnimating) _show();
  }

  @override
  void didUpdateWidget(EmojiPuzzle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revealed && !oldWidget.revealed) {
      _show();
    } else if (!widget.revealed) {
      _controller.value = 0;
    }
  }

  void _show() {
    final count = _emoji.length;
    final animate =
        widget.animate && !MediaQuery.disableAnimationsOf(context) && count > 0;
    if (!animate) {
      _controller.value = 1;
      return;
    }
    if (_controller.value > 0) return;
    _controller
      ..duration = EmojiPuzzle.pop + EmojiPuzzle.stagger * (count - 1)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final emoji = _emoji;
    final total =
        EmojiPuzzle.pop.inMicroseconds +
        EmojiPuzzle.stagger.inMicroseconds * math.max(0, emoji.length - 1);
    return Semantics(
      label: widget.revealed
          ? l10n.gameEmojiSemantics(widget.emoji)
          : l10n.gameEmojiHidden,
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, glyph) in emoji.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.xxs),
                child: widget.revealed
                    ? _Pop(
                        key: ValueKey('emoji-$index'),
                        animation: CurvedAnimation(
                          parent: _controller,
                          curve: Interval(
                            EmojiPuzzle.stagger.inMicroseconds * index / total,
                            (EmojiPuzzle.stagger.inMicroseconds * index +
                                    EmojiPuzzle.pop.inMicroseconds) /
                                total,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                        child: Text(
                          glyph,
                          style: TextStyle(fontSize: widget.size, height: 1.2),
                        ),
                      )
                    : Container(
                        key: ValueKey('emoji-hidden-$index'),
                        width: widget.size * 1.1,
                        height: widget.size * 1.2,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(Radii.sm),
                        ),
                        child: Text(
                          '?',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Scales and tilts one emoji in as [animation] runs from 0 to 1.
class _Pop extends AnimatedWidget {
  const _Pop({
    super.key,
    required Animation<double> animation,
    required this.child,
  }) : super(listenable: animation);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.rotate(
        angle: (1 - t) * -0.35,
        child: Transform.scale(scale: t.clamp(0.0, 1.3), child: child),
      ),
    );
  }
}
