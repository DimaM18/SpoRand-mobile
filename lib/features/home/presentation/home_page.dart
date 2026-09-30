import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/router/routes.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/theme/app_theme.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/ui.dart';
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
    final scheme = theme.colorScheme;
    final gutter = Spacing.gutter(MediaQuery.sizeOf(context).width);
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
          padding: EdgeInsets.fromLTRB(gutter, Spacing.xs, gutter, Spacing.xl),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ExcludeSemantics(
                child: EqualizerBars(
                  animate: !Motion.reduced(context),
                  width: 72,
                  height: 28,
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.5,
              child: GradientHeadline(l10n.homeHeadline),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              l10n.homeSubtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            PartyButton(
              label: l10n.homeCreateRoom,
              icon: Icons.add_rounded,
              glow: true,
              onPressed: () => showCreateRoomSheet(context),
            ),
            const SizedBox(height: Spacing.sm),
            OutlinedButton.icon(
              onPressed: () => context.push(Routes.mySongs),
              icon: const Icon(Icons.queue_music_rounded),
              label: Text(l10n.homeMySongs),
            ),
            const SizedBox(height: Spacing.lg),
            PartyCard(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(Icons.login_rounded, color: scheme.primary),
                      ),
                      const SizedBox(width: Spacing.xs),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            l10n.homeJoinTitle,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.md),
                  RoomCodeField(
                    controller: _code,
                    label: l10n.homeJoinCodeLabel,
                    error: _invalidCode ? l10n.homeJoinCodeInvalid : null,
                    onChanged: (_) {
                      if (_invalidCode) setState(() => _invalidCode = false);
                    },
                    onSubmitted: (_) => _join(),
                  ),
                  const SizedBox(height: Spacing.md),
                  OutlinedButton.icon(
                    onPressed: _join,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(l10n.homeJoinAction),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The room-code field: big, spaced, tabular Nunito 800 so a code read
/// aloud across the room is easy to type; the error sits under it with an
/// icon. [новое имя — согласовать]
class RoomCodeField extends StatelessWidget {
  const RoomCodeField({
    super.key,
    required this.controller,
    required this.label,
    this.error,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? error;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final error = this.error;
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.go,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[0-9A-Za-z-]')),
        LengthLimitingTextInputFormatter(7),
      ],
      style: theme.textTheme.headlineSmall?.tabular.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 6,
      ),
      decoration: InputDecoration(
        labelText: label,
        error: error == null
            ? null
            : Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.error_rounded,
                      size: IconSizes.sm,
                      color: scheme.error,
                    ),
                  ),
                  const SizedBox(width: Spacing.xxs),
                  Expanded(
                    child: Text(
                      error,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ),
                ],
              ),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
