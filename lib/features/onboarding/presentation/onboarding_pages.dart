import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/bootstrap/presentation/widgets/boot_status_view.dart';
import 'package:sporand/app/router/routes.dart';
import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/features/onboarding/domain/age_gate.dart';
import 'package:sporand/features/onboarding/presentation/onboarding_controller.dart';

/// Shared onboarding layout: step dots, title, body, bottom action.
class _OnboardingScaffold extends StatelessWidget {
  const _OnboardingScaffold({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.action,
  });

  final int step;
  final String title;
  final String subtitle;
  final Widget body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final party = PartyColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.lg,
            Spacing.lg,
            Spacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (var i = 0; i < 2; i++)
                    AnimatedContainer(
                      duration: Motion.medium,
                      margin: const EdgeInsets.only(right: Spacing.xs),
                      width: i == step ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: i == step
                            ? LinearGradient(colors: party.gradient)
                            : null,
                        color: i == step
                            ? null
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Spacing.xl),
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.displaySmall),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.xl),
              Expanded(child: SingleChildScrollView(child: body)),
              action,
            ],
          ),
        ),
      ),
    );
  }
}

class AgeGatePage extends ConsumerStatefulWidget {
  const AgeGatePage({super.key});

  @override
  ConsumerState<AgeGatePage> createState() => _AgeGatePageState();
}

class _AgeGatePageState extends ConsumerState<AgeGatePage> {
  final TextEditingController _year = TextEditingController();
  bool _invalid = false;
  bool _submitting = false;

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final result = await ref
        .read(onboardingControllerProvider.notifier)
        .submitBirthYear(_year.text);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _invalid = result is AgeGateInvalid;
    });
    switch (result) {
      case AgeGateInvalid():
        break;
      case AgeGateBlocked():
        context.go(Routes.onboardingBlocked);
      case AgeGateAccepted():
        context.go(Routes.onboardingConsent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _OnboardingScaffold(
      step: 0,
      title: l10n.onboardingAgeTitle,
      subtitle: l10n.onboardingAgeSubtitle,
      body: TextField(
        controller: _year,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        style: Theme.of(context).textTheme.headlineMedium,
        decoration: InputDecoration(
          labelText: l10n.onboardingAgeFieldLabel,
          hintText: l10n.onboardingAgeFieldHint,
          errorText: _invalid ? l10n.onboardingAgeInvalid : null,
        ),
        onChanged: (_) {
          if (_invalid) setState(() => _invalid = false);
        },
        onSubmitted: (_) => _submit(),
      ),
      action: FilledButton(
        onPressed: _submitting ? null : _submit,
        child: Text(l10n.onboardingContinue),
      ),
    );
  }
}

class ConsentPage extends ConsumerWidget {
  const ConsentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    return _OnboardingScaffold(
      step: 1,
      title: l10n.onboardingConsentTitle,
      subtitle: l10n.onboardingConsentBody,
      body: state.canChooseAnalytics
          ? Card(
              child: SwitchListTile(
                value: state.analyticsOptIn,
                onChanged: controller.setAnalyticsOptIn,
                title: Text(l10n.onboardingConsentAnalytics),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.lg),
                ),
              ),
            )
          : Text(
              l10n.onboardingConsentMinorNote,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
      action: FilledButton(
        onPressed: state.busy
            ? null
            : () async {
                final next = await controller.complete();
                if (context.mounted) context.go(next);
              },
        child: Text(l10n.onboardingConsentStart),
      ),
    );
  }
}

/// Under 13: the app is blocked; the answer is remembered.
class AgeBlockedPage extends StatelessWidget {
  const AgeBlockedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      child: BootStatusScaffold(
        child: BootStatusView(
          icon: Icons.front_hand_rounded,
          title: l10n.onboardingBlockedTitle,
          message: l10n.onboardingBlockedBody,
        ),
      ),
    );
  }
}
