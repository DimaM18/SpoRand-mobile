import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/net/protocol/emoji_text.dart';
import 'package:sporand/core/net/protocol/json_read.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';

import '../../support/protocol_samples.dart';

void main() {
  group('isEmojiPrompt (packages/protocol emoji/catalog.ts)', () {
    test('accepts 2-6 emoji with optional spaces', () {
      for (final text in [
        '🎭🎼👑',
        '🎭 🎼 👑',
        '👨‍👩‍👧🏠',
        '🇵🇱🎤',
        '1️⃣🌙',
        '👍🏽💃🕺🎶🎵🎸',
      ]) {
        expect(isEmojiPrompt(text), isTrue, reason: text);
      }
      expect(emojiGraphemes('👨‍👩‍👧🏠'), hasLength(2));
    });

    test('rejects letters, digits, punctuation and wrong counts', () {
      for (final text in [
        'Queen 👑🎼',
        '👑🎼!',
        '👑7',
        '👑',
        '🎭🎼👑🎭🎼👑🎭',
        '',
        '   ',
        'Ы👑',
      ]) {
        expect(isEmojiPrompt(text), isFalse, reason: text);
      }
    });
  });

  test('round.prepare: an emoji round needs a valid emoji_prompt and no '
      'owner; emoji_prompt only in an emoji round', () {
    final valid = Samples.emojiPrepare(startAtMonoUs: 1).toJson();
    expect(RoundPrepare.fromJson(valid).emojiPrompt?.emoji, '🎭🎼👑');

    Map<String, Object?> changed(Map<String, Object?> changes) =>
        Map<String, Object?>.of(valid)..addAll(changes);
    for (final bad in [
      changed({'emoji_prompt': null}),
      changed({
        'emoji_prompt': {'emoji': 'Queen 👑'},
      }),
      changed({'you_are_owner': true}),
      changed({'audio_start_source': 'scheduled'}),
      changed({'prompt': 'whose_song'}),
    ]) {
      bad.removeWhere((_, v) => v == null);
      expect(
        () => RoundPrepare.fromJson(bad),
        throwsA(isA<ProtocolFormatException>()),
        reason: '$bad',
      );
    }
  });
}
