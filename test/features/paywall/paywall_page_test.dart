import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/router/app_router.dart';
import 'package:sporand/app/router/routes.dart';
import 'package:sporand/core/ui/ui.dart';

import '../../support/app_harness.dart';
import '../../support/fake_services.dart';
import '../../support/round_screen_harness.dart' show loadBundledFonts;

/// The paywall's package cards with the bundled fonts: the trial chip keeps
/// a single-line label at the default text scale (it sits under the price,
/// with the whole card width), and large text still fits.
void main() {
  setUpAll(loadBundledFonts);

  Future<void> openPaywall(
    WidgetTester tester, {
    required Size size,
    required double textScale,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = await launch(
      tester,
      FakeServices(
        prefs: {'age_band': '18_plus', 'onboarding_completed': true},
      ),
    );
    unawaited(
      container.read(routerProvider).push(Routes.paywallFor('settings')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  final trial = find.text('3 дня бесплатно');

  for (final width in [360.0, 390.0]) {
    testWidgets('$width dp at text scale 1.0: the trial chip is one line, '
        'under the price', (tester) async {
      await openPaywall(tester, size: Size(width, 800), textScale: 1);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(trial);
      await tester.pumpAndSettle();
      final chip = find.ancestor(of: trial, matching: find.byType(StatusChip));
      expect(tester.getSize(chip).height, lessThanOrEqualTo(32.5));
      final price = find.text(r'$24.99 в год');
      expect(price, findsOneWidget);
      expect(
        tester.getRect(chip).top,
        greaterThanOrEqualTo(
          tester.getRect(find.text('Premium на год')).bottom - 0.5,
        ),
        reason: 'the chip no longer takes half of the title row',
      );
      expect(
        tester.getRect(chip).left,
        greaterThanOrEqualTo(tester.getRect(price).left),
      );
    });
  }

  testWidgets('360x640 at text scale 2.0: the cards lay out without overflow '
      'and the trial label stays whole', (tester) async {
    await openPaywall(tester, size: const Size(360, 640), textScale: 2);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      trial,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(trial, findsOneWidget);
  });
}
