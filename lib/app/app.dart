import 'package:material_ui/material_ui.dart';
import 'package:mobile_kit/mobile_kit.dart' show KitApp;

import 'package:sporand/app/bootstrap/bootstrap.dart';

/// The app widget: mobile_kit's `KitApp` (wave 8b: `MaterialApp.router`
/// over the kit router with SpoRand's title, «Neon Night+» themes,
/// localizations and reduced-motion scope) with [sporandAppConfig].
class SporandApp extends StatelessWidget {
  const SporandApp({super.key});

  @override
  Widget build(BuildContext context) => KitApp(config: sporandAppConfig);
}
