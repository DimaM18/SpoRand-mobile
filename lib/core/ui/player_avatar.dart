import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/theme/tokens.dart';

/// A role badge at the avatar's bottom-right. The row text next to the
/// avatar always states the role too.
enum PlayerBadge { host, dj, ready, away }

/// A monogram circle (design system §6.6): the first grapheme of [name] in
/// `onSurface` on a neutral `surfaceContainerHighest` disc with an
/// `outline` edge. No photos and no external images.
///
/// Never one of the six answer colours: in «Чья песня?» the answers are the
/// players, so a colour must not mean «Celina» in the standings and «slot
/// D» in the next round (and hashed colours collided). The name next to the
/// avatar identifies the player.
///
/// Decorative for screen readers: the surrounding row names the player,
/// «Ты» and the role. [isMe] adds a 2 dp `primary` ring.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.playerId,
    required this.name,
    this.size = 40,
    this.isMe = false,
    this.badge,
  });

  /// Standings 32, lists 40, podium 56.
  final double size;
  final String playerId;
  final String name;
  final bool isMe;
  final PlayerBadge? badge;

  /// The monogram: the first grapheme, upper-cased; «?» for a blank name.
  static String monogram(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ring = isMe ? 2.0 : 0.0;
    final disc = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring == 0 ? 0 : ring + 1),
      decoration: isMe
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scheme.primary, width: ring),
            )
          : null,
      child: DecoratedBox(
        key: const ValueKey('avatar-disc'),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outline),
        ),
        child: Center(
          child: MediaQuery.withNoTextScaling(
            child: Text(
              monogram(name),
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.42,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
    final badge = this.badge;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: badge == null
            ? disc
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  disc,
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: _Badge(badge: badge),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.badge});

  final PlayerBadge badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final game = GameColors.of(context);
    final l10n = context.l10n;
    final (icon, fill, on, tooltip) = switch (badge) {
      PlayerBadge.host => (
        Icons.star_rounded,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        l10n.playerBadgeHost,
      ),
      PlayerBadge.dj => (
        Icons.headphones_rounded,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        l10n.playerBadgeDj,
      ),
      PlayerBadge.ready => (
        Icons.check_rounded,
        game.correct,
        game.onCorrect,
        l10n.playerBadgeReady,
      ),
      PlayerBadge.away => (
        Icons.wifi_off_rounded,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        l10n.lobbyAway,
      ),
    };
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.surface, width: 1.5),
        ),
        child: Icon(icon, size: 13, color: on),
      ),
    );
  }
}
