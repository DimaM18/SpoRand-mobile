import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/ui.dart';

/// iOS «Reduce Motion» arrives as `AccessibilityFeatures.reduceMotion` and
/// never sets `MediaQuery.disableAnimations` (the Flutter docs say so), so
/// the app folds it in at the top ([ReduceMotionScope]).
void main() {
  Widget app(Widget home) => MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => ReduceMotionScope(child: child!),
    home: Scaffold(body: Center(child: home)),
  );

  Widget probe() => Builder(
    builder: (context) => Text(
      'reduced=${Motion.reduced(context)} '
      'media=${MediaQuery.disableAnimationsOf(context)}',
      textDirection: TextDirection.ltr,
    ),
  );

  testWidgets('iOS Reduce Motion reaches Motion.reduced and '
      'MediaQuery.disableAnimations, and follows live changes', (tester) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(app(probe()));
    expect(find.text('reduced=false media=false'), findsOneWidget);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    await tester.pump();
    expect(find.text('reduced=true media=true'), findsOneWidget);

    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    await tester.pump();
    expect(find.text('reduced=false media=false'), findsOneWidget);
  });

  testWidgets('Motion.reduced reads iOS Reduce Motion even without the '
      'scope', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: probe())),
      ),
    );
    expect(find.textContaining('reduced=true'), findsOneWidget);
  });

  testWidgets('under iOS Reduce Motion the equalizer is static and a '
      'pressed answer tile keeps its size', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EqualizerBars(animate: !Motion.reduced(context)),
              SizedBox(
                width: 320,
                child: AnswerTile(
                  key: const ValueKey('tile'),
                  label: 'Option A',
                  index: 0,
                  mode: AnswerTileMode.open,
                  clock: FakeInputClock(anchorUs: 0),
                  onCommit: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('tile'))),
    );
    await tester.pump();
    final scale = tester.widget<AnimatedScale>(
      find.descendant(
        of: find.byKey(const ValueKey('tile')),
        matching: find.byType(AnimatedScale),
      ),
    );
    expect(scale.scale, 1);
    await gesture.up();
    await tester.pump();
  });
}
