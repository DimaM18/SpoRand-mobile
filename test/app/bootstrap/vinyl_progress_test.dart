import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/bootstrap/presentation/widgets/vinyl_progress.dart';
import 'package:sporand/app/theme/app_theme.dart';

/// Counts how often each of [targets] is painted while [body] runs.
Future<List<int>> countPaints(
  List<RenderObject> targets,
  Future<void> Function() body,
) async {
  final paints = List<int>.filled(targets.length, 0);
  debugOnProfilePaint = (object) {
    final index = targets.indexWhere((t) => identical(t, object));
    if (index >= 0) paints[index]++;
  };
  try {
    await body();
  } finally {
    debugOnProfilePaint = null;
  }
  return paints;
}

Future<void> pumpVinyl(WidgetTester tester, {required double progress}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Center(child: VinylProgress(progress: progress, animate: true)),
      ),
    );

void main() {
  // Regression: the ring (two blurred arcs) and the spinning disc shared one
  // repaint boundary, so every rotation frame re-recorded the ring too.
  testWidgets('the spinning disc repaints neither the ring nor the static '
      'disc', (tester) async {
    await pumpVinyl(tester, progress: 0.5);
    // Let the ring finish easing toward the real progress.
    await tester.pump(const Duration(seconds: 1));

    final paints = find.descendant(
      of: find.byType(VinylProgress),
      matching: find.byType(CustomPaint),
    );
    final ring = tester.renderObject(paints.first);
    final disc = tester.renderObject(paints.at(1));
    final counts = await countPaints([ring, disc], () async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    });

    expect(counts, [0, 0], reason: 'ring and static disc are not repainted');
    expect(tester.hasRunningAnimations, isTrue, reason: 'the disc spins');
  });

  testWidgets('real progress still repaints the ring', (tester) async {
    await pumpVinyl(tester, progress: 0.2);
    await tester.pump(const Duration(seconds: 1));
    final ring = tester.renderObject(
      find
          .descendant(
            of: find.byType(VinylProgress),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    final counts = await countPaints([ring], () async {
      await pumpVinyl(tester, progress: 0.8);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    });
    expect(counts.single, greaterThan(0));
  });
}
