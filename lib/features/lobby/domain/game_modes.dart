import 'package:sporand/core/net/protocol/ws_enums.dart';

/// The modes a mode picker offers (wave 4): the enabled ones
/// (`modes_enabled`: the room's frozen config in the lobby, Remote Config
/// before a room exists), in [GameMode] order, plus [current] when it is
/// already selected, so a room in a hidden mode still shows its mode.
/// Never empty: with nothing enabled the server default applies.
/// [новое имя — согласовать]
List<GameMode> selectableModes({
  required List<GameMode> enabled,
  GameMode? current,
}) {
  final modes = [
    for (final mode in GameMode.values)
      if (enabled.contains(mode) || mode == current) mode,
  ];
  return modes.isEmpty ? defaultEnabledModes : modes;
}

/// The protocol default of `modes_enabled`: guess_track is hidden.
const defaultEnabledModes = [GameMode.whoseSong, GameMode.emojiQuiz];
