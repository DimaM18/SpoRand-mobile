import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/bootstrap/presentation/widgets/boot_status_view.dart';
import 'package:sporand/app/di/providers.dart';
import 'package:sporand/core/l10n/l10n.dart';

// Wave 8b: the maintenance screen is mobile_kit's (same texts and icon; its
// scaffold draws SpoRand's backdrop). [ForceUpdatePage] stays SpoRand's and
// replaces the kit's (`KitPagesSpec.forceUpdate`): the kit's has another
// body text and an «open» icon on its button.
export 'package:mobile_kit/mobile_kit.dart'
    show MaintenancePage, maintenanceLiftedProvider;

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
