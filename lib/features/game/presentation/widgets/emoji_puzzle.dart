import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/protocol/emoji_text.dart';
import 'package:sporand/core/theme/tokens.dart';

/// The emoji line of an emoji_quiz round [новое имя — согласовать].
///
/// Hidden behind «?» tiles until [revealed] (the round opens at the same
/// moment for everyone, so nobody can read the puzzle early), then each
/// emoji pops in (scale 0.85 -> 1 and a fade, no rotation, no overshoot)
/// with a short stagger. With reduced motion (or [animate] false) the
/// emoji simply appear.
///
/// The emoji are quiz content from the system emoji font, never UI icons.
class EmojiPuzzle extends StatefulWidget {
  const EmojiPuzzle({
    super.key,
    required this.emoji,
    required this.revealed,
    this.animate = true,
    this.size = 60,
  });

  final String emoji;
  final bool revealed;
  final bool animate;

  /// Glyph size in dp: 56-64 in a round, 36 in the reveal recap.
  final double size;

  /// The pop of one emoji; each next one starts [stagger] later.
  static const pop = Duration(milliseconds: 240);
  static const stagger = Motion.stagger;

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
    final animate = widget.animate && !Motion.reduced(context) && count > 0;
    if (!animate) {
      _controller.value = 1;
      return;
    }
    if (_controller.value > 0) return;
    _controller
      ..duration = EmojiPuzzle.pop + EmojiPuzzle.stagger * _staggered(count)
      ..forward(from: 0);
  }

  /// Items after the first that get their own delay (at most
  /// [Motion.staggerMaxItems] in total are staggered).
  static int _staggered(int count) =>
      math.max(0, math.min(count, Motion.staggerMaxItems) - 1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final emoji = _emoji;
    final popUs = EmojiPuzzle.pop.inMicroseconds;
    final staggerUs = EmojiPuzzle.stagger.inMicroseconds;
    final total = popUs + staggerUs * _staggered(emoji.length);
    // The slot follows the text scale (the glyph does too); the FittedBox
    // then scales the whole row down to the card, so a large glyph never
    // paints over its neighbour or out of the card.
    final glyphSize = MediaQuery.textScalerOf(context).scale(widget.size);
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
                // One fixed slot for the «?» tile and the glyph, whatever
                // the platform's emoji font measures (colour emoji advance
                // about 1.25 em): the row (and every answer under it) never
                // moves when the puzzle opens.
                child: SizedBox(
                  width: glyphSize * 1.3,
                  height: glyphSize * 1.25,
                  child: widget.revealed
                      ? Center(
                          child: _Pop(
                            key: ValueKey('emoji-$index'),
                            animation: CurvedAnimation(
                              parent: _controller,
                              curve: Interval(
                                staggerUs *
                                    math.min(
                                      index,
                                      Motion.staggerMaxItems - 1,
                                    ) /
                                    total,
                                (staggerUs *
                                            math.min(
                                              index,
                                              Motion.staggerMaxItems - 1,
                                            ) +
                                        popUs) /
                                    total,
                                curve: Curves.easeOut,
                              ),
                            ),
                            child: Text(
                              glyph,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              style: TextStyle(
                                fontSize: widget.size,
                                height: 1.2,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          key: ValueKey('emoji-hidden-$index'),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(Radii.sm),
                            border: Border.all(color: scheme.outline),
                          ),
                          child: Text(
                            '?',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
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

/// Scales one emoji from 0.85 to 1 and fades it in as [animation] runs
/// from 0 to 1. Never rotates or overshoots.
class _Pop extends AnimatedWidget {
  const _Pop({
    super.key,
    required Animation<double> animation,
    required this.child,
  }) : super(listenable: animation);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value.clamp(0.0, 1.0);
    return Opacity(
      opacity: t,
      child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
    );
  }
}
