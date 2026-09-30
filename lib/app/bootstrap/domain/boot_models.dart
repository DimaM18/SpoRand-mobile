import 'package:sporand/app/bootstrap/domain/init_step.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/app/router/routes.dart';

/// Loader state emitted by the initializer.
final class BootProgress {
  const BootProgress({
    required this.value,
    required this.stage,
    required this.label,
    this.stepId,
  });

  static const initial = BootProgress(
    value: 0,
    stage: InitStage.config,
    label: BootLabel.loadingConfig,
  );

  /// Weighted share of finished steps, 0..1, never decreasing.
  final double value;
  final InitStage stage;
  final BootLabel label;

  /// The step currently running (or the last one that ran).
  final String? stepId;

  @override
  bool operator ==(Object other) =>
      other is BootProgress &&
      other.value == value &&
      other.stage == stage &&
      other.label == label &&
      other.stepId == stepId;

  @override
  int get hashCode => Object.hash(value, stage, label, stepId);

  @override
  String toString() =>
      'BootProgress(${(value * 100).toStringAsFixed(1)}%, $stage, $stepId)';
}

/// Why the app must not be entered normally.
enum BootGate {
  /// `min_supported_app_version` is above the installed version.
  forceUpdate,

  /// `maintenance_mode` kill switch.
  maintenance;

  /// Force update wins: the user can act on it, maintenance they can't.
  BootGate strongest(BootGate? other) =>
      other == BootGate.forceUpdate ? BootGate.forceUpdate : this;
}

/// Where the app goes after boot (`enter_app` / `route`).
sealed class BootDestination {
  const BootDestination();

  String get location;
}

final class HomeDestination extends BootDestination {
  const HomeDestination();

  @override
  String get location => Routes.home;
}

final class OnboardingDestination extends BootDestination {
  const OnboardingDestination({this.pendingLink});

  /// Deep link that will open once onboarding is done.
  final AppLink? pendingLink;

  @override
  String get location => Routes.onboarding;
}

final class AgeBlockedDestination extends BootDestination {
  const AgeBlockedDestination();

  @override
  String get location => Routes.onboardingBlocked;
}

final class DeepLinkDestination extends BootDestination {
  const DeepLinkDestination(this.link);

  final AppLink link;

  @override
  String get location => link.location;
}

final class ForceUpdateDestination extends BootDestination {
  const ForceUpdateDestination();

  @override
  String get location => Routes.forceUpdate;
}

final class MaintenanceDestination extends BootDestination {
  const MaintenanceDestination();

  @override
  String get location => Routes.maintenance;
}

/// Result of one step in one boot attempt.
final class StepRecord {
  const StepRecord({
    required this.stepId,
    required this.stage,
    required this.result,
    required this.duration,
  });

  final String stepId;
  final InitStage stage;
  final StepResult result;
  final Duration duration;
}

final class BootReport {
  const BootReport({
    required this.total,
    required this.records,
    required this.deadlineHit,
    required this.attempt,
  });

  /// Pipeline time, excluding the `boot_min_splash_ms` hold.
  final Duration total;
  final List<StepRecord> records;

  /// `boot_max_total_ms` elapsed and the app entered in degraded mode.
  final bool deadlineHit;
  final int attempt;

  List<String> get degradedStepIds => [
    for (final r in records)
      if (r.result != StepResult.ok) r.stepId,
  ];

  bool get isDegraded => degradedStepIds.isNotEmpty;
}

sealed class BootOutcome {
  const BootOutcome();
}

final class BootSucceeded extends BootOutcome {
  const BootSucceeded(this.destination, this.report);

  final BootDestination destination;
  final BootReport report;
}

/// A critical step failed; the pipeline can be retried from that step.
final class BootCriticalFailure extends BootOutcome {
  const BootCriticalFailure({
    required this.stepId,
    required this.result,
    this.error,
  });

  final String stepId;
  final StepResult result;
  final Object? error;
}

/// UI-facing boot state (Riverpod `BootController`).
sealed class BootState {
  const BootState();

  BootProgress get progress;
}

final class BootIdle extends BootState {
  const BootIdle();

  @override
  BootProgress get progress => BootProgress.initial;
}

final class BootRunning extends BootState {
  const BootRunning(this.progress);

  @override
  final BootProgress progress;
}

final class BootFailed extends BootState {
  const BootFailed(this.progress, {required this.stepId});

  @override
  final BootProgress progress;
  final String stepId;
}

final class BootCompleted extends BootState {
  const BootCompleted(this.progress, this.destination, this.report);

  @override
  final BootProgress progress;
  final BootDestination destination;
  final BootReport report;
}
