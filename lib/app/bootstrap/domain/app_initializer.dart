import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';

import 'package:sporand/app/bootstrap/domain/boot_models.dart';
import 'package:sporand/app/bootstrap/domain/boot_telemetry.dart';
import 'package:sporand/app/bootstrap/domain/init_context.dart';
import 'package:sporand/app/bootstrap/domain/init_step.dart';
import 'package:sporand/core/analytics/analytics_events.dart';

typedef StepErrorHandler = void Function(
  String stepId,
  Object error,
  StackTrace? stack,
);

/// Runs the boot pipeline (R-BOOT, brief §3 "Boot pipeline").
///
/// - Stages run in order: config -> warmup -> sdk_init -> enter_app.
/// - Inside config/warmup, steps run in parallel as soon as their
///   [InitStep.dependsOn] are settled; sdk_init runs strictly in order.
/// - Every step has a timeout. A non-critical failure or timeout is recorded
///   as degraded and the boot continues; a critical one stops the boot and
///   [retry] resumes from the failed step (finished steps are not re-run).
/// - `boot_max_total_ms`: when it passes, unfinished non-critical steps are
///   abandoned (recorded as `timeout`) and the app is entered in degraded
///   mode. Critical steps are still awaited, each bounded by its own
///   timeout, because the app cannot work without them.
/// - `boot_min_splash_ms`: enter_app is held until the splash has been
///   visible that long, so a fast boot does not flicker (and `route` still
///   sees deep links received during the hold).
/// - `app_init_step` / `app_init_completed` are buffered until the analytics
///   SDK is initialized, then flushed in order.
///
/// Pure Dart: time comes from `package:clock` and timers, so tests drive it
/// with fake_async.
class AppInitializer {
  AppInitializer({
    required List<InitStep> steps,
    required this.context,
    required this._telemetry,
    this.onStepError,
  }) : _steps = List.unmodifiable(steps) {
    _validate();
    _totalWeight = _steps.fold<double>(0, (sum, step) => sum + step.weight);
  }

  final InitContext context;
  final List<InitStep> _steps;
  final BootTelemetry _telemetry;
  final StepErrorHandler? onStepError;
  late final double _totalWeight;
  late final Map<String, InitStep> _byId = {
    for (final step in _steps) step.id: step,
  };

  final StreamController<BootProgress> _progress =
      StreamController<BootProgress>.broadcast();
  BootProgress _current = BootProgress.initial;

  /// Steps with a final result (ok/degraded/failed/timeout, non-retryable).
  final Map<String, StepRecord> _finished = {};

  /// Steps skipped because a force-update/maintenance gate is active.
  final Set<String> _skipped = {};
  final Map<String, Future<_StepRun>> _inFlight = {};
  final Map<String, Stopwatch> _running = {};
  final Set<String> _abandoned = {};

  /// Abandoned before they ever started; see [completeDeferredSteps].
  final List<InitStep> _neverStarted = [];
  final List<(String, Map<String, Object>)> _pendingTelemetry = [];

  int _attempt = 0;
  bool _isRunning = false;
  bool _deadlineHit = false;
  BootCriticalFailure? _attemptFailure;
  InitStage _stage = InitStage.config;
  String? _lastStepId;

  Stream<BootProgress> get progress => _progress.stream;
  BootProgress get currentProgress => _current;
  int get attempt => _attempt;

  /// Finished steps in declaration order.
  List<StepRecord> get records => [
    for (final step in _steps) ?_finished[step.id],
  ];

  /// Telemetry still waiting for analytics (visible for tests/diagnostics).
  List<(String, Map<String, Object>)> get pendingTelemetry =>
      List.unmodifiable(_pendingTelemetry);

  Future<BootOutcome> run() async {
    if (_isRunning) throw StateError('AppInitializer is already running');
    _isRunning = true;
    _attempt++;
    _deadlineHit = false;
    _attemptFailure = null;
    final elapsed = clock.stopwatch()..start();
    try {
      for (final stage in InitStage.values) {
        if (stage == InitStage.enterApp) continue;
        final failure = await _runStageWithDeadline(stage, elapsed);
        if (failure != null) return failure;
      }

      // The boot_min_splash_ms hold happens *before* enter_app, so `route`
      // drains the deep-link queue at the last possible moment: a link that
      // arrives while the splash is held is still delivered.
      _stage = InitStage.enterApp;
      _emit();
      final hold = clock.stopwatch()..start();
      final minSplash = context.timings.minSplash;
      if (elapsed.elapsed < minSplash) {
        await Future<void>.delayed(minSplash - elapsed.elapsed);
      }
      hold.stop();

      // enter_app runs even after the deadline: the user must land somewhere.
      final routeFailure = await _runStage(
        InitStage.enterApp,
        _pendingSteps(InitStage.enterApp),
      );
      if (routeFailure != null) return routeFailure;

      // Pipeline time only; the splash hold is not boot work.
      final total = elapsed.elapsed - hold.elapsed;

      final report = BootReport(
        total: total,
        records: records,
        deadlineHit: _deadlineHit,
        attempt: _attempt,
      );
      _pendingTelemetry.add((
        AnalyticsEvents.appInitCompleted,
        {
          AnalyticsParams.totalMs: total.inMilliseconds,
          // Retries happen in an already-running process.
          AnalyticsParams.coldStart: _attempt == 1,
          AnalyticsParams.degradedSteps: report.degradedStepIds.join(','),
        },
      ));
      flushTelemetry();
      _emit(complete: true);
      return BootSucceeded(
        context.destination ?? const HomeDestination(),
        report,
      );
    } finally {
      _isRunning = false;
    }
  }

  /// Resumes after a [BootCriticalFailure]; finished steps are kept.
  Future<BootOutcome> retry() => run();

  /// Sends buffered telemetry if analytics is ready.
  void flushTelemetry() {
    if (!_telemetry.isReady) return;
    final events = List.of(_pendingTelemetry);
    _pendingTelemetry.clear();
    for (final (event, params) in events) {
      try {
        _telemetry.log(event, params);
      } catch (error, stack) {
        // Telemetry must never break the boot.
        onStepError?.call('telemetry', error, stack);
      }
    }
  }

  /// After a degraded entry (deadline hit), runs the steps that never got to
  /// start, in declaration order (which keeps the sdk_init order), without
  /// blocking the UI. Their `timeout` telemetry is not rewritten.
  Future<void> completeDeferredSteps() async {
    final steps = List<InitStep>.of(_neverStarted);
    _neverStarted.clear();
    for (final step in steps) {
      if (context.gate != null && !step.runsWhenGated) continue;
      try {
        await step.run(context).timeout(step.timeoutFor(context));
      } catch (error, stack) {
        onStepError?.call(step.id, error, stack);
      }
    }
  }

  Future<void> dispose() => _progress.close();

  Future<BootCriticalFailure?> _runStageWithDeadline(
    InitStage stage,
    Stopwatch elapsed,
  ) async {
    final pending = _pendingSteps(stage);
    if (pending.isEmpty) return null;
    if (_deadlineHit) return _enterDegraded(stage);
    final remaining = context.timings.maxTotal - elapsed.elapsed;
    if (remaining <= Duration.zero) {
      _deadlineHit = true;
      return _enterDegraded(stage);
    }
    BootCriticalFailure? failure;
    final work = _runStage(stage, pending).then((f) => failure = f);
    if (await _completesWithin(work, remaining)) return failure;
    _deadlineHit = true;
    return _enterDegraded(stage);
  }

  Future<BootCriticalFailure?> _runStage(
    InitStage stage,
    List<InitStep> steps,
  ) {
    if (steps.isEmpty) return Future.value();
    _stage = stage;
    _emit();
    // Once boot_max_total_ms has passed, the deadline path owns the
    // pre-enter stages; enter_app always runs to completion.
    final stopOnDeadline = stage != InitStage.enterApp;
    return stage.isSequential
        ? _runSequential(steps, stopOnDeadline: stopOnDeadline)
        : _runParallel(steps, stopOnDeadline: stopOnDeadline);
  }

  Future<BootCriticalFailure?> _runSequential(
    List<InitStep> steps, {
    required bool stopOnDeadline,
  }) async {
    for (final step in steps) {
      if (stopOnDeadline && _deadlineHit) return null;
      final run = await _start(step);
      if (run.criticalFailure) return _attemptFailure;
    }
    return null;
  }

  Future<BootCriticalFailure?> _runParallel(
    List<InitStep> steps, {
    required bool stopOnDeadline,
  }) {
    final waiting = List<InitStep>.of(steps);
    final done = Completer<BootCriticalFailure?>();
    var active = 0;

    void pump() {
      if (done.isCompleted || (stopOnDeadline && _deadlineHit)) return;
      if (_attemptFailure == null) {
        for (final step in List<InitStep>.of(waiting)) {
          if (!step.dependsOn.every(_isSettled)) continue;
          waiting.remove(step);
          active++;
          unawaited(
            _start(step).then((_) {
              active--;
              pump();
            }),
          );
        }
      }
      // After a critical failure we still wait for running siblings so a
      // retry never overlaps with work from this attempt.
      if (active == 0) done.complete(_attemptFailure);
    }

    pump();
    return done.future;
  }

  /// `boot_max_total_ms` passed: abandon non-critical work, finish critical
  /// work, then let `enter_app` route in degraded mode.
  Future<BootCriticalFailure?> _enterDegraded(InitStage fromStage) async {
    for (final id in _inFlight.keys.toList()) {
      final step = _byId[id]!;
      if (!step.critical) _abandon(step, _running[id]?.elapsed);
    }
    for (final MapEntry(:key, :value) in _inFlight.entries.toList()) {
      if (_byId[key]!.critical) await value;
    }
    if (_attemptFailure case final failure?) return failure;
    for (final stage in InitStage.values) {
      if (stage.index < fromStage.index || stage == InitStage.enterApp) {
        continue;
      }
      for (final step in _pendingSteps(stage)) {
        if (_inFlight.containsKey(step.id)) continue;
        if (!step.critical) {
          _abandon(step, Duration.zero);
          _neverStarted.add(step);
          continue;
        }
        _stage = stage;
        final run = await _start(step);
        if (run.criticalFailure) return _attemptFailure;
      }
    }
    return null;
  }

  Future<_StepRun> _start(InitStep step) {
    final completer = Completer<_StepRun>();
    // Registered before the step body starts so progress sees it in flight.
    _inFlight[step.id] = completer.future;
    completer.complete(_execute(step));
    return completer.future;
  }

  Future<_StepRun> _execute(InitStep step) async {
    final watch = clock.stopwatch()..start();
    _running[step.id] = watch;
    _lastStepId = step.id;
    _emit();

    StepResult result;
    Object? error;
    StackTrace? stack;
    try {
      result =
          await step.run(context).timeout(step.timeoutFor(context)) ??
          StepResult.ok;
    } on TimeoutException {
      result = StepResult.timeout;
    } catch (e, s) {
      result = StepResult.failed;
      error = e;
      stack = s;
    }
    watch.stop();
    _running.remove(step.id);
    unawaited(_inFlight.remove(step.id));
    if (error != null) onStepError?.call(step.id, error, stack);

    if (_abandoned.contains(step.id)) {
      // Already recorded as `timeout` when boot_max_total_ms passed.
      return _StepRun(result, criticalFailure: false);
    }
    final criticalFailure =
        step.critical &&
        (result == StepResult.failed || result == StepResult.timeout);
    _logStep(step, result, watch.elapsed);
    if (criticalFailure) {
      _attemptFailure ??= BootCriticalFailure(
        stepId: step.id,
        result: result,
        error: error,
      );
    } else {
      _finished[step.id] = StepRecord(
        stepId: step.id,
        stage: step.stage,
        result: result,
        duration: watch.elapsed,
      );
    }
    _emit();
    flushTelemetry();
    return _StepRun(result, criticalFailure: criticalFailure);
  }

  void _abandon(InitStep step, Duration? ranFor) {
    if (_finished.containsKey(step.id)) return;
    final duration = ranFor ?? Duration.zero;
    _abandoned.add(step.id);
    _finished[step.id] = StepRecord(
      stepId: step.id,
      stage: step.stage,
      result: StepResult.timeout,
      duration: duration,
    );
    _logStep(step, StepResult.timeout, duration);
    _emit();
    flushTelemetry();
  }

  List<InitStep> _pendingSteps(InitStage stage) {
    final gated =
        context.gate != null &&
        stage != InitStage.config &&
        stage != InitStage.enterApp;
    final pending = <InitStep>[];
    var skippedAny = false;
    for (final step in _steps) {
      if (step.stage != stage || _isSettled(step.id)) continue;
      if (gated && !step.runsWhenGated) {
        _skipped.add(step.id);
        skippedAny = true;
        continue;
      }
      pending.add(step);
    }
    if (skippedAny) _emit();
    return pending;
  }

  bool _isSettled(String id) =>
      _finished.containsKey(id) || _skipped.contains(id);

  void _logStep(InitStep step, StepResult result, Duration duration) {
    _pendingTelemetry.add((
      AnalyticsEvents.appInitStep,
      {
        AnalyticsParams.step: step.id,
        AnalyticsParams.stage: step.stage.wireName,
        AnalyticsParams.durationMs: duration.inMilliseconds,
        AnalyticsParams.result: result.wireName,
      },
    ));
  }

  void _emit({bool complete = false}) {
    var done = 0.0;
    for (final step in _steps) {
      if (_isSettled(step.id)) done += step.weight;
    }
    final ratio = _totalWeight == 0 ? 0.0 : done / _totalWeight;
    final value = complete ? 1.0 : math.min(ratio, 1.0);
    final stage = complete ? InitStage.enterApp : _stage;
    final next = BootProgress(
      // Monotonic by construction (settled steps only grow); max() guards it.
      value: math.max(value, _current.value),
      stage: stage,
      label: stage.label,
      stepId: _inFlight.keys.lastOrNull ?? _lastStepId,
    );
    if (next == _current) return;
    _current = next;
    if (!_progress.isClosed) _progress.add(next);
  }

  void _validate() {
    final seen = <String, InitStep>{};
    InitStage? previousStage;
    for (final step in _steps) {
      if (seen.containsKey(step.id)) {
        throw ArgumentError('Duplicate init step id "${step.id}"');
      }
      if (previousStage != null && step.stage.index < previousStage.index) {
        throw ArgumentError('Step "${step.id}" is declared out of stage order');
      }
      for (final dependency in step.dependsOn) {
        if (!seen.containsKey(dependency)) {
          throw ArgumentError(
            'Step "${step.id}" depends on "$dependency", which must be '
            'declared before it',
          );
        }
      }
      seen[step.id] = step;
      previousStage = step.stage;
    }
  }

  static Future<bool> _completesWithin(Future<void> work, Duration limit) {
    final result = Completer<bool>();
    final timer = Timer(limit, () {
      if (!result.isCompleted) result.complete(false);
    });
    unawaited(
      work.then(
        (_) {
          timer.cancel();
          if (!result.isCompleted) result.complete(true);
        },
        onError: (Object error, StackTrace stack) {
          timer.cancel();
          if (!result.isCompleted) result.completeError(error, stack);
        },
      ),
    );
    return result.future;
  }
}

final class _StepRun {
  const _StepRun(this.result, {required this.criticalFailure});

  final StepResult result;
  final bool criticalFailure;
}
