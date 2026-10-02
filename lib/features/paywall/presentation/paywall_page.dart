import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_kit/mobile_kit.dart'
    show PaywallConfig, PaywallPerk, paywallConfigProvider;

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/purchases/purchases_service.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/ui.dart';
import 'package:sporand/features/paywall/domain/paywall_placement.dart';
import 'package:sporand/features/paywall/presentation/paywall_controller.dart';
import 'package:sporand/features/settings/presentation/settings_controller.dart';

/// SpoRand's paywall for mobile_kit (`paywallConfigProvider`): the
/// placements of `paywall_view.placement` and the perks [PaywallPage] lists
/// [новое имя — согласовать].
final sporandPaywallConfig = PaywallConfig(
  placements: [for (final p in PaywallPlacement.values) p.wireName],
  perks: [
    PaywallPerk(id: 'no_ads', label: (context) => context.l10n.paywallPerkNoAds),
    PaywallPerk(id: 'rounds', label: (context) => context.l10n.paywallPerkRounds),
    PaywallPerk(
      id: 'players',
      label: (context) => context.l10n.paywallPerkPlayers,
    ),
  ],
);

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
    final game = GameColors.of(context);
    final gutter = Spacing.gutter(MediaQuery.sizeOf(context).width);

    void snack(String text) => showPartyToast(context, text);

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
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, Spacing.xl),
        children: [
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.5,
            child: GradientHeadline(
              l10n.paywallTitle,
              style: theme.textTheme.headlineLarge,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            l10n.paywallSubtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          for (final perk in ref.watch(paywallConfigProvider).perks)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: game.correct,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      perk.label(context),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Spacing.md),
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
          PartyButton(
            label: l10n.paywallBuy,
            icon: Icons.workspace_premium_rounded,
            glow: true,
            loading: state.purchasing,
            onPressed: buy,
          ),
          const SizedBox(height: Spacing.xs),
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
    final scheme = theme.colorScheme;
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
      // Wave 8b: mobile_kit's catalog type knows products outside the
      // default catalog; SpoRand sells none, so this is never shown.
      PaywallProduct.other => (
        package.title ?? package.productId,
        package.priceLabel,
      ),
    };
    final trialDays = package.trialDays;
    // Selected: a 2 dp neon edge (decorative) plus the radio icon and the
    // selected flag, so the state never rests on colour alone.
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.lg),
          gradient: selected
              ? LinearGradient(colors: party.neonGradient)
              : null,
          color: selected ? null : scheme.outlineVariant,
        ),
        child: Padding(
          padding: EdgeInsets.all(selected ? 2 : 1),
          child: Material(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(Radii.lg - 2),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72),
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: selected ? scheme.primary : scheme.outline,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: theme.textTheme.titleMedium),
                            // The trial chip follows the price with the
                            // card's whole width, so its label stays on one
                            // line; it wraps below the price when needed.
                            Wrap(
                              spacing: Spacing.sm,
                              runSpacing: Spacing.xxs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  price,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                if (trialDays != null)
                                  StatusChip(
                                    icon: Icons.card_giftcard_rounded,
                                    label: l10n.paywallTrial(trialDays),
                                    tabular: true,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
      spacing: Spacing.xs,
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
            ExcludeSemantics(
              child: Icon(
                Icons.storefront_rounded,
                size: IconSizes.xl,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (label != null) ...[
              const SizedBox(height: Spacing.lg),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
