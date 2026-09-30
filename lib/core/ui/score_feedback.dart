import 'dart:async';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/theme/app_fonts.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/party_chip.dart';

/// The outcome of a round for this player.
enum ResultKind { correct, wrong, noAnswer }

/// The reveal's result pill: icon + word + colour (design system §6.8).
class ResultPill extends StatelessWidget {
  const ResultPill({super.key, required this.kind});

  final ResultKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final game = GameColors.of(context);
    final l10n = context.l10n;
    final (icon, label, fill, on) = switch (kind) {
      ResultKind.correct => (
        Icons.check_circle_rounded,
        l10n.gameTileCorrect,
        game.correct,
        game.onCorrect,
      ),
      ResultKind.wrong => (
        Icons.cancel_rounded,
        l10n.revealWrong,
        game.wrong,
        game.onWrong,
      ),
      ResultKind.noAnswer => (
        Icons.hourglass_empty_rounded,
        l10n.revealNoAnswer,
        scheme.surfaceContainerHigh,
        scheme.onSurfaceVariant,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: TapTargets.min),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.xs,
        ),
        decoration: ShapeDecoration(shape: const StadiumBorder(), color: fill),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(icon, color: on, size: IconSizes.md),
            ),
            const SizedBox(width: Spacing.xs),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: on,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «+120» in `gained`, Unbounded with tabular figures. Counts up over
/// [Motion.slow] unless [animate] is false or reduce-motion is on; screen
/// readers always get the final value.
class PointsGained extends StatelessWidget {
  const PointsGained({super.key, required this.points, this.animate = true});

  final int points;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final game = GameColors.of(context);
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    final format = NumberFormat.decimalPattern(locale);
    String text(int value) => '+${format.format(value)}';
    final style = theme.textTheme.headlineMedium?.copyWith(
      fontFamily: AppFonts.display,
      color: game.gained,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final countUp = animate && !Motion.reduced(context) && points > 0;
    return Semantics(
      label: text(points),
      excludeSemantics: true,
      child: countUp
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: points.toDouble()),
              duration: Motion.slow,
              curve: Motion.emphasizedDecelerate,
              builder: (context, value, _) =>
                  Text(text(value.round()), style: style),
            )
          : Text(text(points), style: style),
    );
  }
}

/// «Серия ×{n}» from the server's `RoundResult.streak` (the client never
/// computes it). Hidden below 2. One 280 ms scale-in from 0.9, skipped
/// under reduce-motion.
class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    if (streak < 2) return const SizedBox.shrink();
    final chip = StatusChip(
      icon: Icons.local_fire_department_rounded,
      label: context.l10n.revealStreak(streak),
      tabular: true,
    );
    if (Motion.reduced(context)) return chip;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1),
      duration: Motion.medium,
      curve: Motion.emphasizedDecelerate,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: chip,
    );
  }
}

/// One [Motion.slow] ring burst in [PartyColors.neonGradient] painted
/// **behind** [child] when [play] is true (a correct answer). Never over
/// content, never confetti over text, never on the player screen. Under
/// reduce-motion only [child] shows (the pill is the static badge).
class CelebrationBurst extends StatefulWidget {
  const CelebrationBurst({super.key, required this.play, required this.child});

  final bool play;
  final Widget child;

  @override
  State<CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<CelebrationBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeStart();
  }

  @override
  void didUpdateWidget(CelebrationBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.play && widget.play) _started = false;
    _maybeStart();
  }

  void _maybeStart() {
    if (_started || !widget.play || Motion.reduced(context)) return;
    _started = true;
    unawaited(_burst.forward(from: 0));
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.play || Motion.reduced(context)) return widget.child;
    final colors = PartyColors.of(context).neonGradient;
    return CustomPaint(
      painter: _BurstPainter(progress: _burst, colors: colors),
      child: widget.child,
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.colors})
    : super(repaint: progress);

  final Animation<double> progress;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0 || t >= 1) return;
    final eased = Curves.easeOutCubic.transform(t);
    final center = size.center(Offset.zero);
    final base = size.shortestSide / 2;
    final radius = base + base * 1.2 * eased;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * (1 - eased) + 1
        ..shader = SweepGradient(
          colors: [
            for (final c in [...colors, colors.first])
              c.withValues(alpha: 1 - t),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.progress != progress || old.colors != colors;
}
