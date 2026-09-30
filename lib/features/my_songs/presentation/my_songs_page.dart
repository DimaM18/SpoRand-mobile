import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/theme/app_theme.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/ui.dart';
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
    final gutter = Spacing.gutter(MediaQuery.sizeOf(context).width);
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
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      Spacing.xs,
                      gutter,
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
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        0,
                        gutter,
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
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  Spacing.xs,
                  gutter,
                  Spacing.md,
                ),
                child: FilledButton(
                  key: const ValueKey('my-songs-save'),
                  onPressed: state.canSave
                      ? () async {
                          final saved = await controller.save();
                          if (!context.mounted) return;
                          showPartyToast(
                            context,
                            saved ? l10n.mySongsSaved : l10n.mySongsSaveFailed,
                          );
                        }
                      : null,
                  child: state.saving
                      ? const InlineSpinner()
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.cloud_off_rounded,
                size: IconSizes.xl,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              context.l10n.mySongsLoadFailed,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Spacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.bootRetry),
            ),
          ],
        ),
      ),
    );
  }
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
    if (state.searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: Spacing.sm),
        child: LinearProgressIndicator(),
      );
    }
    final message = state.searchFailed
        ? l10n.mySongsSearchFailed
        : state.results.isEmpty
        ? l10n.mySongsSearchEmpty
        : null;
    if (message != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                state.searchFailed
                    ? Icons.wifi_off_rounded
                    : Icons.search_off_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
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
                ? SizedBox.square(
                    dimension: TapTargets.min,
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: GameColors.of(context).correct,
                    ),
                  )
                : IconButton(
                    key: ValueKey('add-${song.songId}'),
                    tooltip: state.full
                        ? l10n.mySongsFull(state.limits.max)
                        : l10n.mySongsAdd,
                    icon: const Icon(Icons.add_circle_rounded),
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
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusChip(
            icon: Icons.queue_music_rounded,
            label: l10n.mySongsSelected(state.count, state.limits.max),
            tabular: true,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: Spacing.xs),
          Text(
            hint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: Spacing.xs),
        if (state.picks.isEmpty)
          PartyCard(
            child: Row(
              children: [
                const _SongIcon(),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    l10n.mySongsEmpty(state.limits.min, state.limits.max),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          )
        else
          for (final pick in state.picks) ...[
            ListTile(
              key: ValueKey('pick-${pickId(pick)}'),
              contentPadding: EdgeInsets.zero,
              leading: _PositionBadge(position: pick.position),
              title: Text(pick.title),
              subtitle: Text(pick.artists.join(', ')),
              trailing: IconButton(
                key: ValueKey('remove-${pickId(pick)}'),
                tooltip: l10n.mySongsRemove,
                icon: const Icon(Icons.remove_circle_rounded),
                onPressed: () => controller.remove(pickId(pick)),
              ),
            ),
            if (pick is SongPick) _PickVideo(pick: pick, state: state),
          ],
      ],
    );
  }
}

/// The YouTube video linked to a song pick (wave 4): its title and channel
/// as plain text (never a thumbnail: no YouTube image is shown outside the
/// player), or the button to link one.
class _PickVideo extends ConsumerWidget {
  const _PickVideo({required this.pick, required this.state});

  final SongPick pick;
  final MySongsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final songId = pick.song.songId;
    final videoId = pick.youtubeVideoId;
    if (videoId == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          key: ValueKey('youtube-link-$songId'),
          onPressed: () => showYouTubeLinkDialog(context, pick),
          icon: const Icon(Icons.link_rounded),
          label: Text(l10n.mySongsYouTubeAdd),
        ),
      );
    }
    final video = state.videos[songId];
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: YouTubeVideoText(
        key: ValueKey('youtube-video-$songId'),
        title: video?.title ?? l10n.mySongsYouTubeLinked,
        channel: video?.authorName,
        trailing: IconButton(
          key: ValueKey('youtube-unlink-$songId'),
          tooltip: l10n.mySongsYouTubeRemove,
          icon: Icon(Icons.link_off_rounded, color: theme.colorScheme.error),
          onPressed: () =>
              ref.read(mySongsControllerProvider.notifier).unlinkVideo(songId),
        ),
      ),
    );
  }
}

/// A YouTube video as text only: title and channel.
class YouTubeVideoText extends StatelessWidget {
  const YouTubeVideoText({
    super.key,
    required this.title,
    this.channel,
    this.trailing,
  });

  final String title;
  final String? channel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final channel = this.channel;
    return PartyCard(
      tone: PartyCardTone.raised,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      child: Row(
        children: [
          // A generic video icon: never a YouTube logo or thumbnail.
          ExcludeSemantics(
            child: Icon(
              Icons.ondemand_video_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                if (channel != null)
                  Text(
                    context.l10n.mySongsYouTubeChannel(channel),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Paste a YouTube link, check it with the server, see its title and channel
/// as text, then link it to [pick]. [новое имя — согласовать]
Future<void> showYouTubeLinkDialog(BuildContext context, SongPick pick) =>
    showDialog<void>(
      context: context,
      builder: (context) => _YouTubeLinkDialog(pick: pick),
    );

class _YouTubeLinkDialog extends ConsumerStatefulWidget {
  const _YouTubeLinkDialog({required this.pick});

  final SongPick pick;

  @override
  ConsumerState<_YouTubeLinkDialog> createState() => _YouTubeLinkDialogState();
}

class _YouTubeLinkDialogState extends ConsumerState<_YouTubeLinkDialog> {
  final TextEditingController _link = TextEditingController();
  bool _busy = false;
  YouTubeLinkResult? _result;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (!mounted || text == null || text.isEmpty) return;
    _link.text = text;
    await _check();
  }

  Future<void> _check() async {
    if (_busy || _link.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    final result = await ref
        .read(mySongsControllerProvider.notifier)
        .resolveYouTube(_link.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final result = _result;
    return AlertDialog(
      title: Text(l10n.mySongsYouTubeTitle(widget.pick.song.title)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.mySongsYouTubeHint, style: theme.textTheme.bodyMedium),
            const SizedBox(height: Spacing.sm),
            TextField(
              key: const ValueKey('youtube-link-field'),
              controller: _link,
              enabled: !_busy,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.mySongsYouTubeField,
                suffixIcon: IconButton(
                  key: const ValueKey('youtube-link-paste'),
                  tooltip: l10n.mySongsYouTubePaste,
                  icon: const Icon(Icons.content_paste_rounded),
                  onPressed: _busy ? null : _paste,
                ),
              ),
              onSubmitted: (_) => _check(),
            ),
            const SizedBox(height: Spacing.sm),
            if (_busy) const LinearProgressIndicator(),
            if (result case YouTubeLinkResolved(:final video))
              YouTubeVideoText(title: video.title, channel: video.authorName),
            if (result case YouTubeLinkFailed(:final error))
              Text(
                switch (error) {
                  YouTubeLinkError.invalid => l10n.mySongsYouTubeInvalid,
                  YouTubeLinkError.notFound => l10n.mySongsYouTubeNotFound,
                  YouTubeLinkError.notEmbeddable =>
                    l10n.mySongsYouTubeNotEmbeddable,
                  YouTubeLinkError.failed => l10n.mySongsYouTubeFailed,
                },
                key: const ValueKey('youtube-link-error'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.mySongsYouTubeCancel),
        ),
        if (result is YouTubeLinkResolved)
          FilledButton(
            key: const ValueKey('youtube-link-use'),
            onPressed: () {
              ref
                  .read(mySongsControllerProvider.notifier)
                  .linkVideo(widget.pick.song.songId, result.video);
              Navigator.of(context).pop();
            },
            child: Text(l10n.mySongsYouTubeUse),
          )
        else
          FilledButton(
            key: const ValueKey('youtube-link-check'),
            onPressed: _busy ? null : _check,
            child: Text(l10n.mySongsYouTubeCheck),
          ),
      ],
    );
  }
}

/// A tonal note monogram for a song (never artwork).
class _SongIcon extends StatelessWidget {
  const _SongIcon();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.music_note_rounded,
          color: scheme.onPrimaryContainer,
          size: IconSizes.md,
        ),
      ),
    );
  }
}

/// A pick's position in the list, in tabular figures.
class _PositionBadge extends StatelessWidget {
  const _PositionBadge({required this.position});

  final int position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox.square(
      dimension: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: MediaQuery.withNoTextScaling(
            child: Text(
              '$position',
              style: theme.textTheme.titleMedium?.tabular.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
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
    return PartyCard(
      tone: PartyCardTone.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.visibility_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.mySongsPreviewTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(l10n.mySongsPreviewBody, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
