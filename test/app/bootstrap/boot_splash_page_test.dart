import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/bootstrap/application/boot_controller.dart';
import 'package:sporand/app/bootstrap/domain/boot_models.dart';
import 'package:sporand/app/bootstrap/domain/init_step.dart';
import 'package:sporand/app/bootstrap/presentation/boot_splash_page.dart';
import 'package:sporand/app/theme/app_theme.dart';
import 'package:sporand/core/l10n/l10n.dart';

class FakeBootController extends BootController {
  FakeBootController(this.initial);

  final BootState initial;
  int retries = 0;

  @override
  BootState build() => initial;

  void emit(BootState next) => state = next;

  @override
  Future<void> retry() async => retries++;
}

const warmup = BootRunning(
  BootProgress(
    value: 0.42,
    stage: InitStage.warmup,
    label: BootLabel.warmingUp,
    stepId: 'fonts',
  ),
);

final done = BootCompleted(
  const BootProgress(
    value: 1,
    stage: InitStage.enterApp,
    label: BootLabel.entering,
  ),
  const HomeDestination(),
  const BootReport(
    total: Duration(milliseconds: 900),
    records: [],
    deadlineHit: false,
    attempt: 1,
  ),
);

Future<(FakeBootController, List<String>)> pumpSplash(
  WidgetTester tester, {
  BootState initial = warmup,
  bool reducedMotion = false,
  Locale locale = const Locale('ru'),
}) async {
  final controller = FakeBootController(initial);
  final entered = <String>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [bootControllerProvider.overrideWith(() => controller)],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reducedMotion),
          child: child!,
        ),
        home: BootSplashPage(onEnter: entered.add),
      ),
    ),
  );
  return (controller, entered);
}

Finder semanticsValue(String value) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.value == value,
);

void main() {
  testWidgets('renders the real progress and the localized step label', (
    tester,
  ) async {
    final (controller, _) = await pumpSplash(tester);
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Готовим звуки…'), findsOneWidget);
    expect(semanticsValue('Загрузка: 42%'), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue, reason: 'vinyl spins');

    controller.emit(
      const BootRunning(
        BootProgress(
          value: 0.7,
          stage: InitStage.sdkInit,
          label: BootLabel.connectingServices,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Подключаем сервисы…'), findsOneWidget);
    expect(semanticsValue('Загрузка: 70%'), findsOneWidget);
  });

  testWidgets('is localized (en, pl)', (tester) async {
    await pumpSplash(tester, locale: const Locale('en'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Getting the sounds ready…'), findsOneWidget);

    await pumpSplash(tester, locale: const Locale('pl'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Przygotowujemy dźwięki…'), findsOneWidget);
  });

  testWidgets('reduced motion: nothing loops and the hand-off is instant', (
    tester,
  ) async {
    final (controller, entered) = await pumpSplash(tester, reducedMotion: true);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('Готовим звуки…'), findsOneWidget);

    controller.emit(done);
    await tester.pump();
    expect(entered, ['/home']);
  });

  testWidgets('animated hand-off navigates after the exit animation', (
    tester,
  ) async {
    final (controller, entered) = await pumpSplash(tester);
    controller.emit(done);
    await tester.pump();
    expect(entered, isEmpty, reason: 'exit animation still running');
    await tester.pump(const Duration(milliseconds: 500));
    expect(entered, ['/home']);
  });

  testWidgets('a critical failure shows the retry screen', (tester) async {
    final (controller, _) = await pumpSplash(
      tester,
      initial: const BootFailed(BootProgress.initial, stepId: 'storage_open'),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Не получилось запуститься'), findsOneWidget);
    await tester.tap(find.text('Попробовать снова'));
    expect(controller.retries, 1);
  });
}
