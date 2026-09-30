import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/router/routes.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';
import 'package:sporand/features/lobby/domain/room_navigation.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';
import 'package:sporand/features/lobby/presentation/lobby_controller.dart';

/// Keeps the lobby/game/results screens in step with the room: navigates
/// when the game phase changes, leaves when the room ends, and shows server
/// errors. Wraps each room screen.
class RoomRouteSync extends ConsumerWidget {
  const RoomRouteSync({super.key, required this.roomId, required this.child});

  final String roomId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
      ..listen(gameControllerProvider, (previous, next) {
        final target = roomLocationFor(roomId: roomId, game: next);
        final here = GoRouterState.of(context).uri.path;
        if (here != target && ref.read(roomSessionProvider) != null) {
          context.go(target);
        }
      })
      ..listen(activeRoomProvider, (previous, next) {
        if (next is RoomEnded) {
          _snack(context, roomEndedText(context.l10n, next.reason));
          ref.read(activeRoomProvider.notifier).acknowledgeEnd();
          context.go(Routes.home);
        }
      })
      ..listen(roomErrorsProvider, (previous, next) {
        final error = next.value;
        if (error != null) {
          _snack(context, serverErrorText(context.l10n, error));
        }
      });
    return child;
  }

  static void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
}

String roomEndedText(AppLocalizations l10n, RoomEndReason reason) =>
    switch (reason) {
      RoomEndReason.kicked => l10n.roomEndedKicked,
      RoomEndReason.closed || RoomEndReason.left => l10n.roomEndedClosed,
      RoomEndReason.replaced => l10n.roomEndedReplaced,
      RoomEndReason.versionUnsupported => l10n.roomEndedVersion,
      RoomEndReason.connectionLost => l10n.roomEndedLost,
    };

String serverErrorText(AppLocalizations l10n, ServerError error) =>
    switch (error.code) {
      ErrorCodes.notHost => l10n.errorNotHost,
      ErrorCodes.poolInsufficient => l10n.errorPoolInsufficient,
      ErrorCodes.tierRequired => l10n.errorTierRequired,
      ErrorCodes.playbackUnavailable => l10n.errorPlaybackUnavailable,
      ErrorCodes.invalidState => l10n.errorInvalidState,
      ErrorCodes.rateLimited => l10n.errorRateLimited,
      _ => l10n.errorGeneric,
    };
