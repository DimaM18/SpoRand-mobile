import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/router/routes.dart';
import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/features/lobby/domain/display_name.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';
import 'package:sporand/features/lobby/presentation/join_room_page.dart';
import 'package:sporand/features/lobby/presentation/lobby_page.dart';

Future<void> showCreateRoomSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const CreateRoomSheet(),
    );

/// Mode and display name, then `POST /v1/rooms` and the lobby.
class CreateRoomSheet extends ConsumerStatefulWidget {
  const CreateRoomSheet({super.key});

  @override
  ConsumerState<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends ConsumerState<CreateRoomSheet> {
  late final TextEditingController _name = TextEditingController(
    text: ref.read(userPrefsProvider).displayName ?? '',
  );
  GameMode _mode = GameMode.whoseSong;
  bool _busy = false;
  bool _invalidName = false;
  RoomOpenError? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = DisplayName.validate(_name.text);
    if (name == null) {
      setState(() => _invalidName = true);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(activeRoomProvider.notifier)
        .create(mode: _mode, displayName: name);
    if (!mounted) return;
    switch (result) {
      case RoomOpened(:final roomId):
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.go(Routes.lobby(roomId));
      case RoomOpenFailed(:final error):
        setState(() {
          _busy = false;
          _error = error;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final error = _error;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Spacing.lg,
        0,
        Spacing.lg,
        Spacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.createRoomTitle, style: theme.textTheme.headlineSmall),
          const SizedBox(height: Spacing.md),
          Text(l10n.createRoomModeLabel, style: theme.textTheme.labelLarge),
          const SizedBox(height: Spacing.xs),
          for (final mode in GameMode.values)
            _ModeTile(
              title: gameModeLabel(l10n, mode),
              subtitle: switch (mode) {
                GameMode.whoseSong => l10n.modeWhoseSongHint,
                GameMode.guessTrack => l10n.modeGuessTrackHint,
                GameMode.emojiQuiz => l10n.modeEmojiQuizHint,
              },
              selected: _mode == mode,
              onTap: _busy ? null : () => setState(() => _mode = mode),
            ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _name,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            maxLength: DisplayName.maxLength,
            decoration: InputDecoration(
              labelText: l10n.displayNameLabel,
              errorText: _invalidName ? l10n.displayNameInvalid : null,
            ),
            onChanged: (_) {
              if (_invalidName) setState(() => _invalidName = false);
            },
            onSubmitted: (_) => _create(),
          ),
          if (error != null)
            Text(
              roomOpenErrorText(l10n, error),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          const SizedBox(height: Spacing.md),
          FilledButton(
            onPressed: _busy ? null : _create,
            child: _busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(l10n.createRoomAction),
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      Text(subtitle, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
