import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/theme/app_theme.dart';

/// Pumps [child] in a localized [MaterialApp] with the app theme.
///
/// [size] sets the logical screen size (dp), [textScale] the text scaler
/// and [reduceMotion] `MediaQuery.disableAnimations`.
Future<void> pumpUi(
  WidgetTester tester,
  Widget child, {
  bool dark = true,
  Size size = const Size(412, 915),
  double textScale = 1,
  bool reduceMotion = false,
  bool scroll = true,
  Locale locale = const Locale('ru'),
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
        ),
        child: app!,
      ),
      home: Scaffold(
        body: scroll
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: child,
              )
            : Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}
