import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/app/router/routes.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/ui.dart';
import 'package:sporand/features/lobby/domain/display_name.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';

String roomOpenErrorText(AppLocalizations l10n, RoomOpenError error) =>
    switch (error) {
      RoomOpenError.notFound => l10n.roomErrorNotFound,
      RoomOpenError.full => l10n.roomErrorFull,
      RoomOpenError.locked => l10n.roomErrorLocked,
      RoomOpenError.rateLimited => l10n.roomErrorRateLimited,
      RoomOpenError.network => l10n.roomErrorNetwork,
      RoomOpenError.other => l10n.roomErrorOther,
    };

/// Target of `https://<domain>/j/{room_code}`, the QR code and the home
/// code field: asks for a display name, then `POST /v1/rooms/join`.
class JoinRoomPage extends ConsumerStatefulWidget {
  const JoinRoomPage({
    super.key,
    required this.roomCode,
    this.via = JoinVia.link,
  });

  final String roomCode;
  final JoinVia via;

  @override
  ConsumerState<JoinRoomPage> createState() => _JoinRoomPageState();
}

class _JoinRoomPageState extends ConsumerState<JoinRoomPage> {
  late final TextEditingController _name = TextEditingController(
    text: ref.read(userPrefsProvider).displayName ?? '',
  );
  bool _busy = false;
  bool _invalidName = false;
  RoomOpenError? _error;

  @override
  void initState() {
    super.initState();
    // A link to the room the player is already in just returns to it.
    final session = ref.read(roomSessionProvider);
    if (session != null && session.roomCode == widget.roomCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.lobby(session.roomId));
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _join() async {
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
        .join(roomCode: widget.roomCode, displayName: name, via: widget.via);
    if (!mounted) return;
    switch (result) {
      case RoomOpened(:final roomId):
        context.go(Routes.lobby(roomId));
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
    final gutter = Spacing.gutter(MediaQuery.sizeOf(context).width);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(gutter, Spacing.xs, gutter, Spacing.xl),
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.joinTitle(widget.roomCode),
                style: theme.textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              l10n.joinSubtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            TextField(
              controller: _name,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.go,
              maxLength: DisplayName.maxLength,
              decoration: InputDecoration(
                labelText: l10n.displayNameLabel,
                prefixIcon: const Icon(Icons.badge_rounded),
                errorText: _invalidName ? l10n.displayNameInvalid : null,
              ),
              onChanged: (_) {
                if (_invalidName) setState(() => _invalidName = false);
              },
              onSubmitted: (_) => _join(),
            ),
            if (error != null) ...[
              const SizedBox(height: Spacing.sm),
              PartyBanner(
                icon: Icons.error_rounded,
                tone: PartyBannerTone.error,
                message: roomOpenErrorText(l10n, error),
                action: TextButton(
                  onPressed: _busy ? null : _join,
                  child: Text(l10n.paywallRetry),
                ),
              ),
            ],
            const SizedBox(height: Spacing.lg),
            PartyButton(
              label: l10n.joinAction,
              icon: Icons.login_rounded,
              loading: _busy,
              onPressed: _join,
            ),
          ],
        ),
      ),
    );
  }
}
