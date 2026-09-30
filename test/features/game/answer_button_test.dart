import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/theme/app_theme.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';
import 'package:sporand/features/game/presentation/widgets/round_views.dart';

import '../../support/game_harness.dart';
import '../../support/protocol_samples.dart';

void main() {
  testWidgets('a pointer down on an answer sends round.answer with the '
      "pointer event's timestamp minus the process anchor; the second touch "
      'is ignored', (tester) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add('${call.arguments}');
        }
        return null;
      },
    );
    final h = GameHarness(clock: tester.binding.clock, flush: () {});
    await tester.pump();
    h.welcome();
    await tester.pump();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('ru'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final state = ref.watch(gameControllerProvider);
                return state is GameRoundState
                    ? RoundScreen(state: state)
                    : const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );

    final startAt = h.inputClock.monoNowUs + 100000;
    h.send(Samples.prepare(startAtMonoUs: startAt));
    await tester.pump();
    expect(find.text('Celina'), findsOneWidget);
    expect(find.text('Слушай…'), findsOneWidget);

    // Past start_at_mono_us: the unlock timer fires and the next frame
    // shows enabled buttons.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(find.text('Жми быстрее всех!'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    // The OS stamped the touch 12 ms before Flutter handled it. Pointer
    // events carry raw OS input-clock time; the wire gets it minus the
    // process anchor.
    final tapOsUs = h.inputClock.nowUs - 12000;
    final tapUs = tapOsUs - h.inputClock.anchorUs;
    expect(h.inputClock.anchorUs, isNot(0));
    final finger = TestPointer(1);
    await tester.sendEventToBinding(
      finger.down(
        tester.getCenter(find.byKey(const ValueKey('answer-opt-c'))),
        timeStamp: Duration(microseconds: tapOsUs),
      ),
    );
    await tester.pump();

    // A second finger on another answer must not change it.
    final second = TestPointer(2);
    await tester.sendEventToBinding(
      second.down(
        tester.getCenter(find.byKey(const ValueKey('answer-opt-a'))),
        timeStamp: Duration(microseconds: tapOsUs + 80000),
      ),
    );
    await tester.pump();
    await tester.sendEventToBinding(finger.up());
    await tester.sendEventToBinding(second.up());
    await tester.pump();

    final answer = h.received<RoundAnswer>().single;
    expect(answer.optionId, 'opt-c');
    expect(answer.tapMonoUs, tapUs);
    expect(answer.unlockMonoUs, lessThanOrEqualTo(tapUs));
    expect(answer.unlockMonoUs, greaterThanOrEqualTo(startAt));
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
    expect(find.text('Ответ отправлен'), findsOneWidget);

    h.dispose();
    await tester.pump();
  });
}
