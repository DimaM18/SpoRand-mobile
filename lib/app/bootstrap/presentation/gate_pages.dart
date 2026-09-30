import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/bootstrap/application/boot_controller.dart';
import 'package:sporand/app/bootstrap/presentation/widgets/boot_status_view.dart';
import 'package:sporand/app/di/providers.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/remote_config/remote_config_keys.dart';

/// `min_supported_app_version` is above this build.
class ForceUpdatePage extends ConsumerWidget {
  const ForceUpdatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final storeUrl = ref.watch(appEnvProvider).storeUrl;
    return PopScope(
      canPop: false,
      child: BootStatusScaffold(
        child: BootStatusView(
          icon: Icons.system_update_rounded,
          title: l10n.forceUpdateTitle,
          message: l10n.forceUpdateBody,
          actionLabel: l10n.forceUpdateAction,
          // TODO(owner): STORE_URL_IOS / STORE_URL_ANDROID once listed (Q3).
          onAction: storeUrl == null
              ? null
              : () => ref.read(externalLinkLauncherProvider).open(storeUrl),
        ),
      ),
    );
  }
}

/// Fires when a real-time Remote Config update turns maintenance off.
final maintenanceLiftedProvider = StreamProvider.autoDispose<bool>((ref) {
  final config = ref.watch(remoteConfigProvider);
  return config.onUpdated
      .where((keys) => keys.contains(RcKeys.maintenanceMode.name))
      .map((_) => !config.maintenanceMode);
});

/// `maintenance_mode` kill switch.
class MaintenancePage extends ConsumerWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(maintenanceLiftedProvider, (_, next) {
      if (next.value ?? false) {
        ref.read(bootControllerProvider.notifier).restart();
      }
    });
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      child: BootStatusScaffold(
        child: BootStatusView(
          icon: Icons.construction_rounded,
          title: l10n.maintenanceTitle,
          message: l10n.maintenanceBody,
          actionLabel: l10n.maintenanceRetry,
          onAction: () => ref.read(bootControllerProvider.notifier).restart(),
        ),
      ),
    );
  }
}
