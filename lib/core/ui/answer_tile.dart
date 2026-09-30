import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/answer_marker.dart';
import 'package:sporand/core/ui/timed_tap_target.dart';

/// What an [AnswerTile] shows (design system §6.1).
enum AnswerTileMode {
  /// Before the unlock: readable, not tappable, no opacity.
  locked,

  /// Unlocked and tappable (tonal idle fill).
  open,

  /// The player's pick (full answer fill, «Твой ответ»).
  picked,

  /// Another option after the pick: tokens, never opacity.
  faded,

  /// Reveal recap: the correct option («Верно»).
  correct,

  /// Reveal recap: the player's wrong pick («Мимо»).
  wrong,
}

/// One answer: marker, text and a fixed state slot, so nothing shifts
/// under a finger.
///
/// Input goes through [TimedTapTarget] (`Listener.onPointerDown` +
/// [InputClock]); only [AnswerTileMode.open] is tappable. The mode switch
/// is instant: no `AnimatedOpacity`/`AnimatedContainer`, no slide, and the
/// pressed scale only ever shrinks (0.97, dropped under reduce-motion).
class AnswerTile extends StatelessWidget {
  const AnswerTile({
    super.key,
    required this.label,
    required this.index,
    required this.mode,
    required this.clock,
    required this.onCommit,
  });

  final String label;

  /// The slot (0-based): picks the colour pair, shape and letter.
  final int index;
  final AnswerTileMode mode;
  final InputClock clock;

  /// See [TimedTapTarget.onCommit].
  final void Function(int? tapMonoUs) onCommit;

  /// The minimum height for the current screen: 88 dp, or 76 dp below
  /// [TapTargets.compactHeight] so four tiles stay above the fold.
  static double minHeightOf(BuildContext context) =>
      (MediaQuery.maybeSizeOf(context)?.height ?? double.infinity) <
          TapTargets.compactHeight
      ? TapTargets.answerCompact
      : TapTargets.answer;

  /// The label's text scale cap: already large type (22 sp), and a whole
  /// word must fit the text column of a 360 dp phone.
  static const maxTextScale = 1.5;

  static const _separator = ' — ';

  /// «Title — Artist» (the emoji quiz's `title_artist` labels) split at the
  /// last « — », so every tile shows the title and the artist on their own
  /// lines and no line starts with the dash. Other labels (player names)
  /// come back whole. Display only: screen readers get the full label.
  /// [новое имя — согласовать]
  static (String, String?) splitLabel(String label) {
    final at = label.lastIndexOf(_separator);
    if (at <= 0 || at + _separator.length >= label.length) return (label, null);
    return (label.substring(0, at), label.substring(at + _separator.length));
  }

  /// Reveal recap tiles: information, never a control.
  bool get _recap =>
      mode == AnswerTileMode.correct || mode == AnswerTileMode.wrong;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shape = AnswerShape.forIndex(index);
    final semanticsLabel = l10n.gameAnswerSemantics(shape.label(l10n), label);
    // The state word is the value: VoiceOver reads hints late or never.
    final state = switch (mode) {
      AnswerTileMode.picked => l10n.gameYourPick,
      AnswerTileMode.correct => l10n.gameTileCorrect,
      AnswerTileMode.wrong => l10n.revealWrong,
      _ => null,
    };
    if (_recap) {
      return Semantics(
        container: true,
        label: semanticsLabel,
        value: state,
        excludeSemantics: true,
        child: _AnswerTileBody(tile: this, pressed: false),
      );
    }
    return TimedTapTarget(
      enabled: mode == AnswerTileMode.open,
      selected: mode == AnswerTileMode.picked,
      clock: clock,
      onCommit: onCommit,
      semanticsLabel: semanticsLabel,
      semanticsValue: state,
      builder: (context, pressed) =>
          _AnswerTileBody(tile: this, pressed: pressed),
    );
  }
}

class _AnswerTileBody extends StatelessWidget {
  const _AnswerTileBody({required this.tile, required this.pressed});

  final AnswerTile tile;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final game = GameColors.of(context);
    final l10n = context.l10n;
    final swatch = game.answer(tile.index);
    final dark = theme.brightness == Brightness.dark;

    final Color fill;
    final Color text;
    final BorderSide border;
    Color markerFill = swatch.fill;
    Color markerOn = swatch.on;
    IconData? icon;
    String? caption;
    switch (tile.mode) {
      case AnswerTileMode.locked:
        fill = scheme.surfaceContainer;
        text = scheme.onSurfaceVariant;
        border = BorderSide(color: scheme.outlineVariant, width: 1.5);
      case AnswerTileMode.open:
        fill = pressed
            ? Color.alphaBlend(
                scheme.onSurface.withValues(alpha: dark ? 0.08 : 0.06),
                swatch.tonal,
              )
            : swatch.tonal;
        text = scheme.onSurface;
        border = BorderSide(color: swatch.fill, width: 2);
      case AnswerTileMode.picked:
        fill = swatch.fill;
        text = swatch.on;
        border = BorderSide(color: scheme.onSurface, width: 3);
        markerFill = swatch.on;
        markerOn = swatch.fill;
        icon = Icons.check_circle_rounded;
        caption = l10n.gameYourPick;
      case AnswerTileMode.faded:
        fill = scheme.surfaceContainer;
        text = scheme.onSurfaceVariant;
        border = BorderSide(color: scheme.outlineVariant);
      case AnswerTileMode.correct:
        fill = game.correct;
        text = game.onCorrect;
        border = BorderSide.none;
        markerFill = game.onCorrect;
        markerOn = game.correct;
        icon = Icons.check_circle_rounded;
        caption = l10n.gameTileCorrect;
      case AnswerTileMode.wrong:
        fill = game.wrong;
        text = game.onWrong;
        border = BorderSide.none;
        markerFill = game.onWrong;
        markerOn = game.wrong;
        icon = Icons.cancel_rounded;
        caption = l10n.revealWrong;
    }

    final (title, artist) = AnswerTile.splitLabel(tile.label);
    final radius = BorderRadius.circular(Radii.lg);
    final body = Container(
      constraints: BoxConstraints(minHeight: AnswerTile.minHeightOf(context)),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(color: fill, borderRadius: radius),
      // The border is painted on top so its width never moves the content.
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: border == BorderSide.none
            ? null
            : Border.fromBorderSide(border),
      ),
      child: Row(
        children: [
          AnswerMarker(index: tile.index, color: markerFill, onColor: markerOn),
          const SizedBox(width: Spacing.md),
          Expanded(
            // 22 sp answers grow to 1.5x (33 sp): at 2x a 200 dp column
            // breaks «Bohemian» mid-word. Never truncated either way.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: AnswerTile.maxTextScale,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Never truncated: decoys often differ only in the last
                  // letters. The tile grows instead.
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(color: text),
                  ),
                  if (artist != null)
                    Text(
                      artist,
                      style: theme.textTheme.titleMedium?.copyWith(color: text),
                    ),
                  if (caption != null)
                    Text(
                      caption,
                      style: theme.textTheme.bodySmall?.copyWith(color: text),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: Spacing.xs),
          // Fixed state slot: the label never shifts when an icon appears.
          SizedBox(
            width: IconSizes.lg,
            child: icon == null
                ? null
                : Icon(icon, color: text, size: IconSizes.md),
          ),
        ],
      ),
    );

    final reduce = Motion.reduced(context);
    return AnimatedScale(
      scale: pressed && !reduce ? 0.97 : 1,
      duration: reduce ? Duration.zero : Motion.press,
      curve: Curves.easeOut,
      child: body,
    );
  }
}
