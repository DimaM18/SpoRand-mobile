import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/router/app_router.dart';
import 'package:sporand/app/theme/app_theme.dart';
import 'package:sporand/core/l10n/l10n.dart';

class SporandApp extends ConsumerWidget {
  const SporandApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        // material_ui's delegates (Material + Cupertino + Widgets).
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: resolveAppLocale,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
