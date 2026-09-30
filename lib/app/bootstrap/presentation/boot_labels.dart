import 'package:sporand/app/bootstrap/domain/init_step.dart';
import 'package:sporand/core/l10n/l10n.dart';

extension BootLabelText on BootLabel {
  String text(AppLocalizations l10n) => switch (this) {
    BootLabel.loadingConfig => l10n.bootLabelConfig,
    BootLabel.warmingUp => l10n.bootLabelWarmup,
    BootLabel.connectingServices => l10n.bootLabelSdk,
    BootLabel.entering => l10n.bootLabelEnter,
  };
}
