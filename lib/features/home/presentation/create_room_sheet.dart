import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/router/routes.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/ui.dart';
import 'package:sporand/features/lobby/domain/display_name.dart';
import 'package:sporand/features/lobby/domain/game_modes.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';
import 'package:sporand/features/lobby/presentation/join_room_page.dart';
import 'package:sporand/features/lobby/presentation/lobby_page.dart';

Future<void> showCreateRoomSheet(BuildContext context) => showPartySheet<void>(
  context: context,
  builder: (context) => const CreateRoomSheet(),
);

/// Mode and display name, then `POST /v1/rooms` and the lobby. The form
/// scrolls with large text; «Создать комнату» stays pinned at the bottom.
class CreateRoomSheet extends ConsumerStatefulWidget {
  const CreateRoomSheet({super.key});

  @override
  ConsumerState<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends ConsumerState<CreateRoomSheet> {
  late final TextEditingController _name = TextEditingController(
    text: ref.read(userPrefsProvider).displayName ?? '',
  );

  /// `modes_enabled` from Remote Config (the server checks it too).
  late final List<GameMode> _modes = selectableModes(
    enabled: ref.read(remoteConfigProvider).modesEnabled,
  );
  late GameMode _mode = _modes.first;
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.createRoomTitle,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  l10n.createRoomModeLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                for (final mode in _modes)
                  _ModeTile(
                    key: ValueKey('create-mode-${mode.wire}'),
                    icon: gameModeIcon(mode),
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
                    prefixIcon: const Icon(Icons.badge_rounded),
                    errorText: _invalidName ? l10n.displayNameInvalid : null,
                  ),
                  onChanged: (_) {
                    if (_invalidName) setState(() => _invalidName = false);
                  },
                  onSubmitted: (_) => _create(),
                ),
                if (error != null) ...[
                  const SizedBox(height: Spacing.xs),
                  PartyBanner(
                    icon: Icons.error_rounded,
                    tone: PartyBannerTone.error,
                    message: roomOpenErrorText(l10n, error),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        PartyButton(
          label: l10n.createRoomAction,
          icon: Icons.celebration_rounded,
          compact: true,
          loading: _busy,
          onPressed: _create,
        ),
      ],
    );
  }
}

/// A mode card: icon, title and a one-line description. Selected: a 2 dp
/// `primary` border and a check icon (never colour alone).
class _ModeTile extends StatelessWidget {
  const _ModeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.lg),
      side: selected
          ? BorderSide(color: scheme.primary, width: 2)
          : BorderSide(color: scheme.outlineVariant),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        button: true,
        child: Material(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        icon,
                        size: IconSizes.lg,
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.primary,
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: selected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurface,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: selected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    SizedBox(
                      width: IconSizes.md,
                      child: selected
                          ? ExcludeSemantics(
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: scheme.onPrimaryContainer,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
