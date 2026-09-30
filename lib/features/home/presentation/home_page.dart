import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/bootstrap/presentation/widgets/equalizer_bars.dart';
import 'package:sporand/app/router/routes.dart';
import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/features/home/presentation/create_room_sheet.dart';
import 'package:sporand/features/home/presentation/home_controller.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _code = TextEditingController();
  bool _invalidCode = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(homeControllerProvider).showConsentFormIfRequired();
      }
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _join() {
    final location = ref.read(homeControllerProvider).joinLocation(_code.text);
    if (location == null) {
      setState(() => _invalidCode = true);
      return;
    }
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final party = PartyColors.of(context);
    final animate = !MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: l10n.homeSettingsTooltip,
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push(Routes.settings),
          ),
          const SizedBox(width: Spacing.xs),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.xs,
            Spacing.lg,
            Spacing.xl,
          ),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: EqualizerBars(animate: animate, width: 72, height: 28),
            ),
            const SizedBox(height: Spacing.lg),
            Semantics(
              header: true,
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) =>
                    LinearGradient(colors: party.gradient).createShader(bounds),
                child: Text(
                  l10n.homeHeadline,
                  style: theme.textTheme.displayMedium,
                ),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              l10n.homeSubtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.xl),
            FilledButton.icon(
              onPressed: () => showCreateRoomSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.homeCreateRoom),
            ),
            const SizedBox(height: Spacing.sm),
            OutlinedButton.icon(
              onPressed: () => context.push(Routes.mySongs),
              icon: const Icon(Icons.queue_music_rounded),
              label: Text(l10n.homeMySongs),
            ),
            const SizedBox(height: Spacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.homeJoinTitle, style: theme.textTheme.titleLarge),
                    const SizedBox(height: Spacing.md),
                    TextField(
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.go,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[0-9A-Za-z-]'),
                        ),
                        LengthLimitingTextInputFormatter(7),
                      ],
                      style: theme.textTheme.titleLarge?.copyWith(
                        letterSpacing: 6,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.homeJoinCodeLabel,
                        errorText: _invalidCode
                            ? l10n.homeJoinCodeInvalid
                            : null,
                      ),
                      onChanged: (_) {
                        if (_invalidCode) setState(() => _invalidCode = false);
                      },
                      onSubmitted: (_) => _join(),
                    ),
                    const SizedBox(height: Spacing.md),
                    OutlinedButton(
                      onPressed: _join,
                      child: Text(l10n.homeJoinAction),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
