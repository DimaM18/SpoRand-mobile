import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/flavors/flavor.dart';
import 'package:sporand/app/router/routes.dart';
import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/features/paywall/domain/paywall_placement.dart';
import 'package:sporand/features/settings/presentation/settings_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final env = ref.watch(appEnvProvider);
    final version = ref.watch(appInfoProvider).value?.version;
    final adsRemoved =
        ref.watch(entitlementsProvider).value?.adsRemoved ?? false;
    final termsUrl = env.termsUrl;
    final privacyUrl = env.privacyUrl;

    Future<void> restore() async {
      final outcome = await controller.restorePurchases();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(switch (outcome) {
              RestoreOutcome.restored => l10n.settingsRestoreDone,
              RestoreOutcome.nothingFound => l10n.settingsRestoreNothing,
              RestoreOutcome.failed => l10n.settingsRestoreFailed,
            }),
          ),
        );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Spacing.xl),
        children: [
          _Section(l10n.settingsPrivacySection),
          SwitchListTile(
            value: state.analyticsEnabled && state.analyticsAvailable,
            onChanged: state.analyticsAvailable
                ? controller.setAnalyticsEnabled
                : null,
            title: Text(l10n.settingsAnalyticsTitle),
            subtitle: Text(
              state.analyticsAvailable
                  ? l10n.settingsAnalyticsSubtitle
                  : l10n.settingsAnalyticsUnavailable,
            ),
          ),
          if (state.privacyOptionsRequired)
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.settingsPrivacyOptions),
              onTap: controller.openPrivacyOptions,
            ),
          if (state.purchasesAvailable) ...[
            _Section(l10n.settingsPurchasesSection),
            if (!adsRemoved)
              ListTile(
                leading: const Icon(Icons.block_rounded),
                title: Text(l10n.settingsRemoveAds),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(
                  Routes.paywallFor(PaywallPlacement.settings.wireName),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: Text(l10n.settingsRestorePurchases),
              enabled: !state.busy,
              onTap: restore,
            ),
          ],
          _Section(l10n.settingsAboutSection),
          if (termsUrl != null)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.settingsTerms),
              onTap: () =>
                  ref.read(externalLinkLauncherProvider).open(termsUrl),
            ),
          if (privacyUrl != null)
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: Text(l10n.settingsPrivacyPolicy),
              onTap: () =>
                  ref.read(externalLinkLauncherProvider).open(privacyUrl),
            ),
          if (version != null)
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(l10n.settingsVersion(version)),
              subtitle: state.degradedSteps.isEmpty
                  ? null
                  : Text(l10n.settingsDegraded(state.degradedSteps.join(', '))),
            ),
          // The device timing test (brief §5/§9) runs on test builds only.
          if (kDebugMode || env.flavor != Flavor.prod)
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(l10n.settingsClockCalibration),
              onTap: () => context.push(Routes.debugClock),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.lg,
        Spacing.lg,
        Spacing.xs,
      ),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
