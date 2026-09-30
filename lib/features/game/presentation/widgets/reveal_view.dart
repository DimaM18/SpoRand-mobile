import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/widgets/round_views.dart';
import 'package:sporand/features/game/presentation/widgets/standings_list.dart';

/// `round.reveal`: the correct answer (and owner), this player's points and
/// reaction time, the track with its attribution, and the standings.
class RevealScreen extends ConsumerWidget {
  const RevealScreen({super.key, required this.reveal});

  final RevealView reveal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final result = reveal.myResult;
    final (headline, color) = reveal.wasOwner
        ? (l10n.revealOwnerYou, theme.colorScheme.primary)
        : !reveal.answered
        ? (l10n.revealNoAnswer, theme.colorScheme.onSurfaceVariant)
        : reveal.correct
        ? (l10n.revealCorrect(result?.points ?? 0), theme.colorScheme.tertiary)
        : (l10n.revealWrong, theme.colorScheme.error);
    final reaction = result?.reactionMs;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final correctLabel = reveal.correctLabel;
    final track = reveal.track;
    final attributionUrl = Uri.tryParse(track.attribution.url ?? '');
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.xs,
        Spacing.lg,
        Spacing.xl,
      ),
      children: [
        RoundHeader(round: reveal.round),
        const SizedBox(height: Spacing.md),
        Semantics(
          liveRegion: true,
          child: Text(
            headline,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (reaction != null && reveal.answered)
          Text(
            l10n.revealReaction(
              NumberFormat('0.00', locale).format(reaction / 1000),
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        const SizedBox(height: Spacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reveal.ownerNames.isNotEmpty)
                  Text(
                    l10n.revealOwner(reveal.ownerNames.join(', ')),
                    style: theme.textTheme.titleLarge,
                  )
                else if (correctLabel != null)
                  Text(
                    l10n.revealAnswer(correctLabel),
                    style: theme.textTheme.titleLarge,
                  ),
                const SizedBox(height: Spacing.xs),
                Text(
                  '${track.title} — ${track.artists.join(', ')}',
                  style: theme.textTheme.titleMedium,
                ),
                if (track.attribution.text case final text?) ...[
                  const SizedBox(height: Spacing.xxs),
                  Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (attributionUrl != null && attributionUrl.hasScheme)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => ref
                          .read(externalLinkLauncherProvider)
                          .open(attributionUrl),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(attributionUrl.host),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        Text(l10n.revealStandings, style: theme.textTheme.titleLarge),
        const SizedBox(height: Spacing.xs),
        StandingsList(rows: reveal.standings),
      ],
    );
  }
}
