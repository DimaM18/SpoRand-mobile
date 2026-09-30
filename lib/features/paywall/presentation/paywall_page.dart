import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/purchases/purchases_service.dart';
import 'package:sporand/features/paywall/domain/paywall_placement.dart';
import 'package:sporand/features/paywall/presentation/paywall_controller.dart';
import 'package:sporand/features/settings/presentation/settings_controller.dart';

/// Paywall with the disclosures Apple 3.1.2(c) requires: price, period,
/// trial, auto-renewal terms, Terms and Privacy links, Restore Purchases.
class PaywallPage extends ConsumerWidget {
  const PaywallPage({super.key, required this.placement});

  final PaywallPlacement placement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = paywallControllerProvider(placement);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final theme = Theme.of(context);
    final party = PartyColors.of(context);

    void snack(String text) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    Future<void> buy() async {
      final outcome = await controller.purchaseSelected();
      if (!context.mounted || outcome == null) return;
      switch (outcome) {
        case PurchaseSucceeded():
          snack(l10n.paywallPurchased);
          context.pop();
        case PurchasePending():
          snack(l10n.paywallPending);
        case PurchaseFailed():
          snack(l10n.paywallFailed);
        case PurchaseCancelled():
          break;
      }
    }

    Future<void> restore() async {
      final outcome = await ref
          .read(settingsControllerProvider.notifier)
          .restorePurchases();
      if (!context.mounted) return;
      snack(switch (outcome) {
        RestoreOutcome.restored => l10n.settingsRestoreDone,
        RestoreOutcome.nothingFound => l10n.settingsRestoreNothing,
        RestoreOutcome.failed => l10n.settingsRestoreFailed,
      });
    }

    final Widget body = switch (state) {
      PaywallLoading() => const Center(child: CircularProgressIndicator()),
      PaywallUnavailable() => _Message(text: l10n.paywallUnavailable),
      PaywallLoadFailed() => _Message(
        text: l10n.paywallLoadFailed,
        actionLabel: l10n.paywallRetry,
        onAction: controller.load,
      ),
      PaywallReady() => ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          0,
          Spacing.lg,
          Spacing.xl,
        ),
        children: [
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) =>
                LinearGradient(colors: party.gradient).createShader(bounds),
            child: Text(l10n.paywallTitle, style: theme.textTheme.displaySmall),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            l10n.paywallSubtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          for (final perk in [
            l10n.paywallPerkNoAds,
            l10n.paywallPerkRounds,
            l10n.paywallPerkPlayers,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(perk, style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Spacing.lg),
          for (final package in state.packages)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: _PackageTile(
                package: package,
                selected: package.packageId == state.selectedPackageId,
                onTap: () => controller.select(package.packageId),
              ),
            ),
          const SizedBox(height: Spacing.md),
          FilledButton(
            onPressed: state.purchasing ? null : buy,
            child: state.purchasing
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(l10n.paywallBuy),
          ),
          TextButton(onPressed: restore, child: Text(l10n.paywallRestore)),
          const SizedBox(height: Spacing.sm),
          Text(
            l10n.paywallLegal,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          _LegalLinks(),
        ],
      ),
    };

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(top: false, child: body),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.package,
    required this.selected,
    required this.onTap,
  });

  final PaywallPackage package;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final party = PartyColors.of(context);
    final (title, price) = switch (package.product) {
      PaywallProduct.removeAds => (
        l10n.paywallRemoveAds,
        l10n.paywallRemoveAdsDetail(package.priceLabel),
      ),
      PaywallProduct.premiumMonthly => (
        l10n.paywallPremiumMonthly,
        l10n.paywallPerMonth(package.priceLabel),
      ),
      PaywallProduct.premiumYearly => (
        l10n.paywallPremiumYearly,
        l10n.paywallPerYear(package.priceLabel),
      ),
    };
    final trialDays = package.trialDays;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.lg),
          gradient: selected ? LinearGradient(colors: party.gradient) : null,
          color: selected ? null : theme.colorScheme.outlineVariant,
        ),
        child: Material(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(Radii.lg - 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.lg - 2),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        Text(
                          price,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trialDays != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm,
                        vertical: Spacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Text(
                        l10n.paywallTrial(trialDays),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalLinks extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(appEnvProvider);
    final launcher = ref.read(externalLinkLauncherProvider);
    final terms = env.termsUrl;
    final privacy = env.privacyUrl;
    // TODO(owner): TERMS_URL / PRIVACY_URL are mandatory before store review.
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        if (terms != null)
          TextButton(
            onPressed: () => launcher.open(terms),
            child: Text(context.l10n.settingsTerms),
          ),
        if (privacy != null)
          TextButton(
            onPressed: () => launcher.open(privacy),
            child: Text(context.l10n.settingsPrivacyPolicy),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (label != null) ...[
              const SizedBox(height: Spacing.lg),
              OutlinedButton(onPressed: onAction, child: Text(label)),
            ],
          ],
        ),
      ),
    );
  }
}
