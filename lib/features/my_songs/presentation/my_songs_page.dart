import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/features/my_songs/presentation/my_songs_controller.dart';

/// «Мои песни» (design doc S1.11 `my_songs`, addendum A2.3): search, the
/// selection with remove buttons, and «Что увидят друзья». Songs are shown
/// as title and artists only, never artwork or logos.
class MySongsPage extends ConsumerWidget {
  const MySongsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(mySongsControllerProvider);
    final controller = ref.read(mySongsControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mySongsTitle)),
      body: SafeArea(
        top: false,
        child: state.loadFailed
            ? _LoadFailed(onRetry: controller.load)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pinned above the list so it never scrolls away.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.lg,
                      Spacing.xs,
                      Spacing.lg,
                      Spacing.xs,
                    ),
                    child: TextField(
                      key: const ValueKey('my-songs-search'),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: l10n.mySongsSearchLabel,
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                      onChanged: controller.setQuery,
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.lg,
                        0,
                        Spacing.lg,
                        Spacing.xl,
                      ),
                      children: [
                        _SearchResults(state: state),
                        const SizedBox(height: Spacing.lg),
                        _Selection(state: state),
                        const SizedBox(height: Spacing.lg),
                        const PoolPrivacyNote(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: state.loadFailed
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.lg,
                  Spacing.xs,
                  Spacing.lg,
                  Spacing.md,
                ),
                child: FilledButton(
                  key: const ValueKey('my-songs-save'),
                  onPressed: state.canSave
                      ? () async {
                          final saved = await controller.save();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  saved
                                      ? l10n.mySongsSaved
                                      : l10n.mySongsSaveFailed,
                                ),
                              ),
                            );
                        }
                      : null,
                  child: state.saving
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text(l10n.mySongsSave),
                ),
              ),
            ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.mySongsLoadFailed, textAlign: TextAlign.center),
          const SizedBox(height: Spacing.md),
          FilledButton(onPressed: onRetry, child: Text(context.l10n.bootRetry)),
        ],
      ),
    ),
  );
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.state});

  final MySongsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final controller = ref.read(mySongsControllerProvider.notifier);
    if (state.query.length < MySongsController.minQueryLength) {
      return const SizedBox.shrink();
    }
    if (state.searching) return const LinearProgressIndicator();
    final message = state.searchFailed
        ? l10n.mySongsSearchFailed
        : state.results.isEmpty
        ? l10n.mySongsSearchEmpty
        : null;
    if (message != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final song in state.results)
          ListTile(
            key: ValueKey('song-${song.songId}'),
            contentPadding: EdgeInsets.zero,
            leading: const _SongIcon(),
            title: Text(song.title),
            subtitle: Text(_subtitle(song)),
            trailing: state.isPicked(song.songId)
                ? const Icon(Icons.check_circle_rounded)
                : IconButton(
                    key: ValueKey('add-${song.songId}'),
                    tooltip: state.full
                        ? l10n.mySongsFull(state.limits.max)
                        : l10n.mySongsAdd,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    onPressed: state.full ? null : () => controller.add(song),
                  ),
          ),
      ],
    );
  }

  static String _subtitle(Song song) =>
      [song.artistCredit, if (song.year case final year?) '$year'].join(' · ');
}

class _Selection extends ConsumerWidget {
  const _Selection({required this.state});

  final MySongsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final controller = ref.read(mySongsControllerProvider.notifier);
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final hint = state.hasLegacy
        ? l10n.mySongsLegacyHint
        : state.missing > 0
        ? l10n.mySongsNeedMore(state.missing)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.mySongsSelected(state.count, state.limits.max),
          style: theme.textTheme.titleMedium,
        ),
        if (hint != null)
          Text(
            hint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: Spacing.xs),
        if (state.picks.isEmpty)
          Text(l10n.mySongsEmpty(state.limits.min, state.limits.max))
        else
          for (final pick in state.picks)
            ListTile(
              key: ValueKey('pick-${pickId(pick)}'),
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${pick.position}')),
              title: Text(pick.title),
              subtitle: Text(pick.artists.join(', ')),
              trailing: IconButton(
                key: ValueKey('remove-${pickId(pick)}'),
                tooltip: l10n.mySongsRemove,
                icon: const Icon(Icons.remove_circle_outline_rounded),
                onPressed: () => controller.remove(pickId(pick)),
              ),
            ),
      ],
    );
  }
}

class _SongIcon extends StatelessWidget {
  const _SongIcon();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      backgroundColor: scheme.secondaryContainer,
      child: Icon(Icons.music_note_rounded, color: scheme.onSecondaryContainer),
    );
  }
}

/// «Что увидят друзья» (design doc S1.9): what a pool reveals, and what it
/// never does.
class PoolPrivacyNote extends StatelessWidget {
  const PoolPrivacyNote({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: Spacing.xs),
                Text(
                  l10n.mySongsPreviewTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: Spacing.xs),
            Text(l10n.mySongsPreviewBody),
          ],
        ),
      ),
    );
  }
}
