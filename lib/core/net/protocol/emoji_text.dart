/// Emoji prompts of emoji_quiz rounds: the Dart mirror of packages/protocol
/// `emojiGraphemes` / `isEmojiPrompt` (`src/emoji/catalog.ts`). The server
/// already checks them; the app re-checks so a prompt with letters (which
/// could spell the answer) is dropped like any other malformed frame.
/// [новое имя — согласовать] every name in this file.
library;

import 'package:characters/characters.dart';

/// `EMOJI_PROMPT_MIN_EMOJI` / `EMOJI_PROMPT_MAX_EMOJI`.
abstract final class EmojiPromptLimits {
  static const minEmoji = 2;
  static const maxEmoji = 6;
}

final _keycap = RegExp(r'^[0-9#*]\uFE0F?\u20E3$', unicode: true);
// The analyzer does not know this Unicode property; the VM (like JS) does.
// ignore: valid_regexps
final _pictographicStart = RegExp(r'^\p{Extended_Pictographic}', unicode: true);
final _regionalIndicatorStart = RegExp(
  r'^\p{Regional_Indicator}',
  unicode: true,
);
final _whitespace = RegExp(r'^\s+$', unicode: true);

/// One emoji: a keycap, a flag (regional indicators) or a grapheme cluster
/// that starts with a pictograph.
bool _isEmojiGrapheme(String cluster) =>
    _keycap.hasMatch(cluster) ||
    _pictographicStart.hasMatch(cluster) ||
    _regionalIndicatorStart.hasMatch(cluster);

/// The emoji (grapheme clusters) of [text], whitespace ignored; null when it
/// contains anything else (letters, digits, punctuation).
List<String>? emojiGraphemes(String text) {
  final clusters = [
    for (final cluster in text.characters)
      if (!_whitespace.hasMatch(cluster)) cluster,
  ];
  return clusters.every(_isEmojiGrapheme) ? clusters : null;
}

/// True for 2-6 emoji and nothing else (spaces allowed between them).
bool isEmojiPrompt(String text) {
  final clusters = emojiGraphemes(text);
  return clusters != null &&
      clusters.length >= EmojiPromptLimits.minEmoji &&
      clusters.length <= EmojiPromptLimits.maxEmoji;
}
