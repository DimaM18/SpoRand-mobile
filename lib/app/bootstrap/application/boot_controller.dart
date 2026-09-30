import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sporand/app/bootstrap/domain/app_initializer.dart';
import 'package:sporand/app/bootstrap/domain/boot_models.dart';
import 'package:sporand/app/di/providers.dart';

final bootControllerProvider = NotifierProvider<BootController, BootState>(
  BootController.new,
);

/// Exposes the boot pipeline to the UI as a [BootState].
class BootController extends Notifier<BootState> {
  AppInitializer? _initializer;
  StreamSubscription<BootProgress>? _progress;

  @override
  BootState build() {
    ref.onDispose(() => _progress?.cancel());
    return const BootIdle();
  }

  /// Starts the pipeline once; later calls are ignored.
  Future<void> start() async {
    if (state is! BootIdle) return;
    final initializer = ref.read(appInitializerProvider);
    _initializer = initializer;
    await _progress?.cancel();
    _progress = initializer.progress.listen((progress) {
      if (state is BootRunning || state is BootIdle) {
        state = BootRunning(progress);
      }
    });
    state = BootRunning(initializer.currentProgress);
    await _apply(await initializer.run());
  }

  /// Retry after a critical failure; resumes from the failed step.
  Future<void> retry() async {
    final initializer = _initializer;
    final current = state;
    if (initializer == null || current is! BootFailed) return;
    state = BootRunning(current.progress);
    await _apply(await initializer.retry());
  }

  /// Runs the whole pipeline again with a fresh initializer (e.g. "check
  /// again" on the maintenance screen).
  Future<void> restart() async {
    await _progress?.cancel();
    _progress = null;
    _initializer = null;
    ref.invalidate(appInitializerProvider);
    state = const BootIdle();
    await start();
  }

  Future<void> _apply(BootOutcome outcome) async {
    if (!ref.mounted) return;
    final progress = _initializer?.currentProgress ?? state.progress;
    switch (outcome) {
      case BootSucceeded(:final destination, :final report):
        state = BootCompleted(progress, destination, report);
        if (report.deadlineHit) {
          // Degraded entry: finish what the deadline skipped, off the UI path.
          unawaited(_initializer?.completeDeferredSteps());
        }
      case BootCriticalFailure(:final stepId):
        state = BootFailed(progress, stepId: stepId);
    }
  }
}
