import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_kit/mobile_kit.dart' show KitL10nContext, SplashVisual;

import 'package:sporand/app/bootstrap/application/boot_controller.dart';
import 'package:sporand/app/bootstrap/domain/boot_models.dart';
import 'package:sporand/app/bootstrap/domain/init_step.dart';
import 'package:sporand/app/bootstrap/presentation/boot_labels.dart';
import 'package:sporand/app/bootstrap/presentation/widgets/boot_backdrop.dart';
import 'package:sporand/app/bootstrap/presentation/widgets/boot_status_view.dart';
import 'package:sporand/app/bootstrap/presentation/widgets/vinyl_progress.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/ui.dart';

/// SpoRand's splash artwork for mobile_kit (`splashVisualProvider`): the
/// vinyl ring and the two-glow backdrop. The kit's status screens
/// (maintenance, the age block) draw [SplashVisual.backdrop]
/// [новое имя — согласовать].
final sporandSplashVisual = SplashVisual(
  progress: (context, progress) => VinylProgress(
    progress: progress.value,
    animate: !MediaQuery.disableAnimationsOf(context),
    size: math.min(220.0, MediaQuery.sizeOf(context).shortestSide * 0.56),
  ),
  backdrop: (context) =>
      BootBackdrop(animate: !MediaQuery.disableAnimationsOf(context)),
);

/// The animated loader shown while `AppInitializer` runs (R-BOOT). It
/// replaces mobile_kit's splash on `/boot` (`KitPagesSpec.boot`).
///
/// Performance: the vinyl, ring, equalizer and glow animate inside their
/// own painters and repaint boundaries. Riverpod `select`s rebuild only the
/// ring (on real progress) and the label (on stage change).
///
/// Reduced motion (`MediaQuery.disableAnimations`): nothing loops, the ring
/// jumps to the real value and the hand-off is instant.
class BootSplashPage extends ConsumerStatefulWidget {
  const BootSplashPage({super.key, this.onEnter});

  /// Navigation after the hand-off animation; defaults to `context.go`.
  final ValueChanged<String>? onEnter;

  @override
  ConsumerState<BootSplashPage> createState() => _BootSplashPageState();
}

class _BootSplashPageState extends ConsumerState<BootSplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final CurvedAnimation _exitCurve = CurvedAnimation(
    parent: _exit,
    curve: Curves.easeInCubic,
  );
  bool _handingOff = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(bootControllerProvider);
      if (state is BootCompleted) _handOff(state.destination);
    });
  }

  @override
  void dispose() {
    _exitCurve.dispose();
    _exit.dispose();
    super.dispose();
  }

  Future<void> _handOff(BootDestination destination) async {
    if (_handingOff || !mounted) return;
    _handingOff = true;
    if (!MediaQuery.disableAnimationsOf(context)) {
      try {
        await _exit.forward().orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    final onEnter = widget.onEnter;
    if (onEnter != null) {
      onEnter(destination.location);
    } else {
      context.go(destination.location);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<BootState>(bootControllerProvider, (previous, next) {
      if (next is BootCompleted) _handOff(next.destination);
    });
    final animate = !MediaQuery.disableAnimationsOf(context);
    final failed = ref.watch(
      bootControllerProvider.select((state) => state is BootFailed),
    );
    return Scaffold(
      backgroundColor: PartyColors.of(context).launchBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          BootBackdrop(animate: animate),
          SafeArea(
            child: Center(
              child: AnimatedSwitcher(
                duration: animate ? Motion.medium : Duration.zero,
                switchInCurve: Motion.emphasizedDecelerate,
                child: failed
                    ? const _BootFailure(key: ValueKey('failed'))
                    : _BootLoader(
                        key: const ValueKey('loader'),
                        exit: _exitCurve,
                        animate: animate,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BootLoader extends StatelessWidget {
  const _BootLoader({super.key, required this.exit, required this.animate});

  final Animation<double> exit;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final size = math.min(
      220.0,
      MediaQuery.sizeOf(context).shortestSide * 0.56,
    );
    return FadeTransition(
      opacity: ReverseAnimation(exit),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: 1.12).animate(exit),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProgressVinyl(size: size, animate: animate),
            const SizedBox(height: Spacing.xl + Spacing.xs),
            EqualizerBars(animate: animate),
            const SizedBox(height: Spacing.lg),
            _StepLabel(animate: animate),
          ],
        ),
      ),
    );
  }
}

class _ProgressVinyl extends ConsumerWidget {
  const _ProgressVinyl({required this.size, required this.animate});

  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(
      bootControllerProvider.select((state) => state.progress.value),
    );
    return Semantics(
      label: context.l10n.appTitle,
      value: context.l10n.bootProgressSemantics((progress * 100).round()),
      child: VinylProgress(progress: progress, animate: animate, size: size),
    );
  }
}

class _StepLabel extends ConsumerWidget {
  const _StepLabel({required this.animate});

  final bool animate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = ref.watch(
      bootControllerProvider.select((state) => state.progress.label),
    );
    final theme = Theme.of(context);
    // A short cross-fade (<= 150 ms), no slide; full-strength text.
    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: animate ? Motion.reducedCrossfade : Duration.zero,
        child: Text(
          label.text(context.kitL10n),
          key: ValueKey<BootLabel>(label),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _BootFailure extends ConsumerWidget {
  const _BootFailure({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return BootStatusView(
      icon: Icons.wifi_off_rounded,
      title: l10n.bootFailedTitle,
      message: l10n.bootFailedBody,
      actionLabel: l10n.bootRetry,
      onAction: () => ref.read(bootControllerProvider.notifier).retry(),
    );
  }
}
