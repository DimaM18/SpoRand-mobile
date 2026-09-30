import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/router/routes.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/ui.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';
import 'package:sporand/features/game/presentation/widgets/round_views.dart';
import 'package:sporand/features/paywall/domain/paywall_placement.dart';
import 'package:sporand/features/paywall/presentation/remove_ads_price.dart';

/// `bonus_offer`: the offer card, then who watches and the result. Never a
/// screen with the YouTube player (that one is disposed before).
class BonusScreen extends ConsumerWidget {
  const BonusScreen({super.key, required this.state});

  final GameBonusState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return switch (state.phase) {
      BonusOffered(canWatch: true) => _OfferCard(
        onWatch: ref.read(gameControllerProvider.notifier).requestBonus,
      ),
      BonusOffered() => StatusScreen(
        title: l10n.bonusOfferWaiting,
        icon: Icons.star_rounded,
      ),
      BonusRequested() => StatusScreen(
        title: l10n.bonusYouWatching,
        busy: true,
      ),
      BonusSponsorWatching(:final isMe, :final sponsorName) => StatusScreen(
        title: isMe
            ? l10n.bonusYouWatching
            : l10n.bonusSponsorWatching(sponsorName),
        busy: true,
      ),
      BonusVerifying() => StatusScreen(title: l10n.bonusVerifying, busy: true),
      BonusGrantedPhase(:final sponsorName) => StatusScreen(
        title: l10n.bonusGranted(sponsorName),
        icon: Icons.celebration_rounded,
      ),
      BonusCancelledPhase(:final reason) => StatusScreen(
        title: reason == BonusCancelReason.ssvTimeout
            ? l10n.bonusCancelledSsv
            : l10n.bonusCancelled,
        icon: Icons.hourglass_bottom_rounded,
      ),
    };
  }
}

/// «Посмотри рекламу — +1 раунд для всех» on the text-safe CTA fill. Its
/// button is the inverse: an [PartyColors.onCta] fill with the CTA violet
/// as text (6.12:1).
class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.onWatch});

  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final party = PartyColors.of(context);
    final l10n = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(
          Spacing.gutter(MediaQuery.sizeOf(context).width),
        ),
        child: PartyCard(
          tone: PartyCardTone.cta,
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ExcludeSemantics(
                child: Icon(Icons.play_circle_rounded, size: 56),
              ),
              const SizedBox(height: Spacing.md),
              Text(
                l10n.bonusOfferTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: party.onCta,
                ),
              ),
              const SizedBox(height: Spacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: party.onCta,
                    foregroundColor: party.ctaGradient.first,
                    minimumSize: const Size(64, TapTargets.hero),
                  ),
                  onPressed: onWatch,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l10n.bonusOfferAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `ad_break`: an interstitial may be on screen (the SDK covers the app);
/// players without an ad see «Считаем очки…» and maybe the upsell card.
/// Our interstitial only ever runs here, after the round (and any YouTube
/// player) is gone.
class AdBreakScreen extends ConsumerWidget {
  const AdBreakScreen({super.key, required this.state});

  final GameAdBreakState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(
          Spacing.gutter(MediaQuery.sizeOf(context).width),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: EqualizerBars(
                animate: !Motion.reduced(context),
                width: 96,
                height: 32,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.adBreakCounting,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            if (state.showUpsell) ...[
              const SizedBox(height: Spacing.xl),
              const _RemoveAdsCard(),
            ],
          ],
        ),
      ),
    );
  }
}

/// «Играть без рекламы — <цена>» (`remove_ads`), placement `ad_break`.
class _RemoveAdsCard extends ConsumerWidget {
  const _RemoveAdsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final price = ref.watch(removeAdsPriceProvider).value;
    return PartyCard(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.block_rounded,
                  color: theme.colorScheme.primary,
                  size: IconSizes.lg,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  price == null ? l10n.upsellTitle : l10n.upsellPrice(price),
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          FilledButton.tonal(
            onPressed: () => context.push(
              Routes.paywallFor(PaywallPlacement.adBreak.wireName),
            ),
            child: Text(l10n.upsellAction),
          ),
        ],
      ),
    );
  }
}
