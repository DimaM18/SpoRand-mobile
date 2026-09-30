import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/ui/ui.dart';
import 'package:sporand/features/game/domain/game_state.dart';

import '../../support/protocol_samples.dart';
import '../../support/round_screen_harness.dart';

/// Height budgets of the round screen with the bundled fonts (real text
/// metrics): on a 375x667 phone with a status bar and the game's app bar,
/// the answers are reachable at the unlock without scrolling, and nothing
/// moves when the round opens (design system §4, §7).
Finder _answer(String optionId) => find.byKey(ValueKey('answer-$optionId'));

const _fourOptions = [
  ...Samples.options,
  RoundOption(optionId: 'opt-d', label: 'Dominik'),
];

void main() {
  setUpAll(loadBundledFonts);

  testWidgets('whose_song, 375x667: four 76 dp answers are fully above the '
      'fold at the unlock and do not move from locked to open', (tester) async {
    final h = await pumpRoundScreen(
      tester,
      screen: const Size(375, 667),
      statusBar: 20,
    );
    h.send(
      Samples.prepare(
        startAtMonoUs: h.inputClock.monoNowUs + 100000,
        options: _fourOptions,
      ),
    );
    await tester.pump();
    expect(find.byType(AnswerTimerRing), findsOneWidget);
    final locked = {
      for (final o in _fourOptions)
        o.optionId: tester.getRect(_answer(o.optionId)),
    };

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect((h.state as GameRoundState).phase, isA<RoundOpen>());
    Rect? previous;
    for (final o in _fourOptions) {
      final rect = tester.getRect(_answer(o.optionId));
      expect(rect, locked[o.optionId], reason: 'no movement at the unlock');
      expect(rect.height, 76, reason: 'compact tiles below 700 dp');
      expect(rect.bottom, lessThanOrEqualTo(667), reason: o.label);
      if (previous != null) {
        expect(rect.top - previous.bottom, greaterThanOrEqualTo(8));
      }
      previous = rect;
    }
    await endRoundScreen(tester, h);
  });

  testWidgets('emoji round, 375x667: the puzzle card with 56 dp emoji and '
      'four long answers; each shows at least a full 48 dp touch target '
      'above the fold, and nothing moves at the unlock', (tester) async {
    final h = await pumpRoundScreen(
      tester,
      screen: const Size(375, 667),
      room: Samples.room(
        mode: GameMode.emojiQuiz,
        state: RoomState.roundPlaying,
      ),
      statusBar: 20,
    );
    h.send(
      Samples.emojiPrepare(startAtMonoUs: h.inputClock.monoNowUs + 100000),
    );
    await tester.pump();
    final locked = {
      for (final o in Samples.emojiOptions)
        o.optionId: tester.getRect(_answer(o.optionId)),
    };
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect((h.state as GameRoundState).phase, isA<RoundOpen>());
    expect(tester.widget<Text>(find.text('🎭')).style?.fontSize, 56);
    for (final o in Samples.emojiOptions) {
      final rect = tester.getRect(_answer(o.optionId));
      expect(rect, locked[o.optionId], reason: 'no movement at the unlock');
      expect(667 - rect.top, greaterThanOrEqualTo(48), reason: o.label);
    }
    await endRoundScreen(tester, h);
  });

  testWidgets('youtube DJ, 375x667: «Музыка играет!» is fully above the '
      'fold under the edge-to-edge player', (tester) async {
    final h = await pumpRoundScreen(
      tester,
      screen: const Size(375, 667),
      me: Samples.hostId,
      room: Samples.youtubeRoom(),
      statusBar: 20,
    );
    h.send(
      Samples.youtubeDjPrepare(startAtMonoUs: h.inputClock.monoNowUs + 2500000),
    );
    await tester.pump();
    await tester.pump();
    final player = tester.getRect(
      find.byKey(const ValueKey('youtube-player-tEsTvIdEo01')),
    );
    expect(player.width, 375);
    final button = tester.getRect(
      find.byKey(const ValueKey('dj-music-playing')),
    );
    expect(button.top, greaterThanOrEqualTo(player.bottom + 16));
    expect(button.bottom, lessThanOrEqualTo(667));
    await endRoundScreen(tester, h);
  });
}
