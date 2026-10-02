import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/app/bootstrap/domain/app_initializer.dart';
import 'package:sporand/app/bootstrap/domain/boot_models.dart';
import 'package:sporand/app/bootstrap/domain/boot_telemetry.dart';
import 'package:sporand/app/bootstrap/domain/init_step.dart';
import 'package:sporand/core/analytics/analytics_events.dart';

import '../../support/fake_services.dart';

/// Records when each synthetic step starts and ends (fake milliseconds).
class Timeline {
  Timeline() : _origin = clock.now();

  final DateTime _origin;
  final List<String> events = [];
  final Map<String, int> starts = {};
  final Map<String, int> ends = {};
  final Map<String, int> runs = {};

  int get now => clock.now().difference(_origin).inMilliseconds;
}

InitStep fakeStep(
  Timeline t,
  String id,
  InitStage stage, {
  int ms = 0,
  bool critical = false,
  double weight = 1,
  Set<String> dependsOn = const {},
  int timeoutMs = 1000,
  Object? Function(int run)? failOnRun,
  void Function()? onStart,
}) => InitStep(
  id: id,
  stage: stage,
  timeout: Duration(milliseconds: timeoutMs),
  critical: critical,
  weight: weight,
  dependsOn: dependsOn,
  body: (ctx) async {
    final run = t.runs[id] = (t.runs[id] ?? 0) + 1;
    t.starts[id] = t.now;
    t.events.add('start:$id');
    onStart?.call();
    if (ms > 0) await Future<void>.delayed(Duration(milliseconds: ms));
    t.ends[id] = t.now;
    t.events.add('end:$id');
    final error = failOnRun?.call(run);
    if (error != null) throw error;
    return null;
  },
);

/// Starts [initializer] and returns a getter for its (eventual) outcome.
BootOutcome? Function() start(AppInitializer initializer) {
  BootOutcome? outcome;
  unawaited(initializer.run().then((o) => outcome = o));
  return () => outcome;
}

AppInitializer initializerFor(
  List<InitStep> steps, {
  FakeServices? services,
  BootTelemetry? telemetry,
}) => AppInitializer(
  steps: steps,
  context: (services ?? FakeServices()).context(),
  telemetry: telemetry ?? RecordingBootTelemetry(ready: true),
);

void main() {
  group('AppInitializer ordering', () {
    test('runs stages in order config -> warmup -> sdk_init -> enter_app', () {
      fakeAsync((async) {
        final t = Timeline();
        final init = initializerFor([
          fakeStep(t, 'c_slow', InitStage.config, ms: 300),
          fakeStep(t, 'c_fast', InitStage.config, ms: 10),
          fakeStep(t, 'w', InitStage.warmup, ms: 10),
          fakeStep(t, 's', InitStage.sdkInit, ms: 10),
          fakeStep(t, 'r', InitStage.enterApp, ms: 10),
        ]);
        final outcome = start(init);
        async.elapse(const Duration(seconds: 5));

        expect(outcome(), isA<BootSucceeded>());
        // warmup waits for the whole config stage, not just the fast step.
        expect(t.starts['w'], 300);
        expect(t.starts['s'], 310);
        // enter_app starts once boot_min_splash_ms (800 ms) has passed, so
        // `route` sees deep links received while the splash was held.
        expect(t.starts['r'], 800);
        expect(
          t.events.indexOf('end:c_slow'),
          lessThan(t.events.indexOf('start:w')),
        );
        expect(
          t.events.indexOf('end:w'),
          lessThan(t.events.indexOf('start:s')),
        );
        expect(
          t.events.indexOf('end:s'),
          lessThan(t.events.indexOf('start:r')),
        );
      });
    });

    test('runs independent config and warmup steps in parallel, honouring '
        'dependencies', () {
      fakeAsync((async) {
        final t = Timeline();
        final init = initializerFor([
          fakeStep(t, 'a', InitStage.config, ms: 100),
          fakeStep(t, 'b', InitStage.config, ms: 100),
          fakeStep(t, 'c', InitStage.config, ms: 50, dependsOn: {'a', 'b'}),
          fakeStep(t, 'w1', InitStage.warmup, ms: 200),
          fakeStep(t, 'w2', InitStage.warmup, ms: 200),
          fakeStep(t, 'w3', InitStage.warmup, ms: 200),
        ]);
        final outcome = start(init);
        async.elapse(const Duration(seconds: 5));

        expect(outcome(), isA<BootSucceeded>());
        expect(t.starts['a'], 0);
        expect(t.starts['b'], 0);
        expect(t.starts['c'], 100);
        expect(
          [t.starts['w1'], t.starts['w2'], t.starts['w3']],
          [150, 150, 150],
        );
        // Sequential execution would have ended at 950 ms.
        expect(t.ends['w3'], 350);
      });
    });

    test('runs sdk_init strictly in declaration order', () {
      fakeAsync((async) {
        final t = Timeline();
        final init = initializerFor([
          fakeStep(t, 'crash_reporting', InitStage.sdkInit, ms: 300),
          fakeStep(t, 'analytics', InitStage.sdkInit, ms: 10),
          fakeStep(t, 'consent', InitStage.sdkInit, ms: 100),
          fakeStep(t, 'ads', InitStage.sdkInit, ms: 5),
        ]);
        final outcome = start(init);
        async.elapse(const Duration(seconds: 5));

        expect(outcome(), isA<BootSucceeded>());
        expect(t.starts, {
          'crash_reporting': 0,
          'analytics': 300,
          'consent': 310,
          'ads': 410,
        });
      });
    });

    test('rejects dependencies that are not declared earlier', () {
      final t = Timeline();
      expect(
        () => initializerFor([
          fakeStep(t, 'a', InitStage.config, dependsOn: {'b'}),
          fakeStep(t, 'b', InitStage.config),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('AppInitializer failures', () {
    test('a non-critical timeout degrades and the boot continues', () {
      fakeAsync((async) {
        final t = Timeline();
        final telemetry = RecordingBootTelemetry(ready: true);
        final init = initializerFor([
          fakeStep(t, 'slow', InitStage.warmup, ms: 5000, timeoutMs: 1000),
          fakeStep(t, 'broken', InitStage.warmup, failOnRun: (_) => 'boom'),
          fakeStep(t, 'after', InitStage.sdkInit),
        ], telemetry: telemetry);
        final outcome = start(init);
        async.elapse(const Duration(seconds: 2));

        final result = outcome()! as BootSucceeded;
        expect(t.starts['after'], 1000);
        expect(result.report.degradedStepIds, ['slow', 'broken']);
        final stepResults = {
          for (final (name, params) in telemetry.events)
            if (name == AnalyticsEvents.appInitStep)
              params['step']: params['result'],
        };
        expect(stepResults, {
          'slow': 'timeout',
          'broken': 'failed',
          'after': 'ok',
        });
        final completed = telemetry.events.last;
        expect(completed.$1, AnalyticsEvents.appInitCompleted);
        expect(completed.$2['degraded_steps'], 2);
        expect(completed.$2['degraded_step_ids'], 'slow,broken');
      });
    });

    test('a critical failure stops the boot; retry resumes from that step', () {
      fakeAsync((async) {
        final t = Timeline();
        final init = initializerFor([
          fakeStep(t, 'config', InitStage.config),
          fakeStep(
            t,
            'storage_open',
            InitStage.warmup,
            critical: true,
            failOnRun: (run) => run == 1 ? StateError('disk') : null,
          ),
          fakeStep(t, 'fonts', InitStage.warmup, ms: 50),
          fakeStep(t, 'crash_reporting', InitStage.sdkInit),
        ]);
        final progress = <double>[];
        init.progress.listen((p) => progress.add(p.value));

        var outcome = start(init);
        async.elapse(const Duration(seconds: 5));
        final failure = outcome()! as BootCriticalFailure;
        expect(failure.stepId, 'storage_open');
        expect(failure.result, StepResult.failed);
        expect(t.runs['crash_reporting'], isNull);
        // Parallel siblings finished before the failure was reported.
        expect(t.runs['fonts'], 1);

        outcome = start(init);
        async.elapse(const Duration(seconds: 5));
        expect(outcome(), isA<BootSucceeded>());
        expect(t.runs, {
          'config': 1,
          'storage_open': 2,
          'fonts': 1,
          'crash_reporting': 1,
        });
        expect(progress, orderedEquals([...progress]..sort()));
        expect(progress.last, 1.0);
      });
    });

    test('a critical timeout is a critical failure', () {
      fakeAsync((async) {
        final t = Timeline();
        final init = initializerFor([
          fakeStep(
            t,
            'route',
            InitStage.enterApp,
            critical: true,
            ms: 3000,
            timeoutMs: 1000,
          ),
        ]);
        final outcome = start(init);
        async.elapse(const Duration(seconds: 2));
        final failure = outcome()! as BootCriticalFailure;
        expect(failure.result, StepResult.timeout);
      });
    });
  });

  group('AppInitializer timing', () {
    test('holds completion until boot_min_splash_ms (default 800 ms)', () {
      fakeAsync((async) {
        final t = Timeline();
        final init = initializerFor([
          fakeStep(t, 'config', InitStage.config, ms: 100),
        ]);
        final outcome = start(init);
        async.elapse(const Duration(milliseconds: 799));
        expect(outcome(), isNull);
        async.elapse(const Duration(milliseconds: 1));
        final result = outcome()! as BootSucceeded;
        // total_ms reports pipeline time, not the splash hold.
        expect(result.report.total, const Duration(milliseconds: 100));
      });
    });

    test('uses boot_min_splash_ms from Remote Config', () {
      fakeAsync((async) {
        final services = FakeServices();
        services.rcBackend.pushUpdate({'boot_min_splash_ms': '1500'});
        final init = initializerFor([
          fakeStep(Timeline(), 'config', InitStage.config),
        ], services: services);
        final outcome = start(init);
        async.elapse(const Duration(milliseconds: 1499));
        expect(outcome(), isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(outcome(), isA<BootSucceeded>());
      });
    });

    test('enters degraded after boot_max_total_ms', () {
      fakeAsync((async) {
        final t = Timeline();
        final services = FakeServices();
        services.rcBackend.pushUpdate({'boot_max_total_ms': '3000'});
        final init = initializerFor([
          fakeStep(t, 'config', InitStage.config, ms: 100),
          fakeStep(
            t,
            'precache_images',
            InitStage.warmup,
            ms: 10000,
            timeoutMs: 20000,
          ),
          fakeStep(t, 'crash_reporting', InitStage.sdkInit),
          fakeStep(t, 'route', InitStage.enterApp, critical: true),
        ], services: services);
        final outcome = start(init);
        async.elapse(const Duration(milliseconds: 2999));
        expect(outcome(), isNull);
        async.elapse(const Duration(milliseconds: 1));

        final result = outcome()! as BootSucceeded;
        expect(result.report.deadlineHit, isTrue);
        final byId = {
          for (final r in result.report.records) r.stepId: r.result,
        };
        expect(byId['precache_images'], StepResult.timeout);
        expect(byId['crash_reporting'], StepResult.timeout);
        expect(
          t.runs['crash_reporting'],
          isNull,
          reason: 'abandoned unstarted',
        );
        expect(t.runs['route'], 1, reason: 'enter_app always runs');

        // The skipped SDK step is completed in the background afterwards.
        unawaited(init.completeDeferredSteps());
        async.flushMicrotasks();
        expect(t.runs['crash_reporting'], 1);
      });
    });

    test('still awaits critical steps after boot_max_total_ms', () {
      fakeAsync((async) {
        final t = Timeline();
        final services = FakeServices();
        services.rcBackend.pushUpdate({'boot_max_total_ms': '3000'});
        final init = initializerFor([
          fakeStep(t, 'config', InitStage.config, ms: 100),
          fakeStep(
            t,
            'storage_open',
            InitStage.warmup,
            critical: true,
            ms: 3500,
            timeoutMs: 5000,
          ),
          fakeStep(t, 'fonts', InitStage.warmup, ms: 10000, timeoutMs: 20000),
        ], services: services);
        final outcome = start(init);
        async.elapse(const Duration(milliseconds: 3599));
        expect(outcome(), isNull);
        async.elapse(const Duration(milliseconds: 1));
        final result = outcome()! as BootSucceeded;
        final byId = {
          for (final r in result.report.records) r.stepId: r.result,
        };
        expect(byId, {
          'config': StepResult.ok,
          'storage_open': StepResult.ok,
          'fonts': StepResult.timeout,
        });
      });
    });
  });

  group('AppInitializer progress and telemetry', () {
    test('progress is weighted, monotonic and ends at 1.0', () {
      fakeAsync((async) {
        final t = Timeline();
        final init = initializerFor([
          fakeStep(t, 'a', InitStage.config, ms: 10, weight: 1),
          fakeStep(t, 'b', InitStage.config, ms: 20, weight: 3),
          fakeStep(t, 'c', InitStage.warmup, ms: 10, weight: 4),
          fakeStep(t, 'd', InitStage.sdkInit, ms: 10, weight: 2),
        ]);
        final updates = <BootProgress>[];
        init.progress.listen(updates.add);
        final outcome = start(init);
        async.elapse(const Duration(seconds: 2));
        expect(outcome(), isA<BootSucceeded>());

        final values = updates.map((p) => p.value).toList();
        expect(values, orderedEquals([...values]..sort()));
        expect(values.toSet(), containsAll(<double>[0.1, 0.4, 0.8, 1.0]));
        expect(values.last, 1.0);
        final sdk = updates.firstWhere((p) => p.stepId == 'd');
        expect(sdk.label, BootLabel.connectingServices);
        expect(updates.last.label, BootLabel.entering);
      });
    });

    test('telemetry is buffered until analytics is ready, then flushed in '
        'order', () {
      fakeAsync((async) {
        final t = Timeline();
        final telemetry = RecordingBootTelemetry();
        int? seenBeforeAnalytics;
        int? seenWhenAfterStarted;
        final init = initializerFor([
          fakeStep(t, 'config_fetch', InitStage.config, ms: 10),
          fakeStep(t, 'crash_reporting', InitStage.sdkInit),
          fakeStep(
            t,
            'analytics',
            InitStage.sdkInit,
            onStart: () {
              seenBeforeAnalytics = telemetry.events.length;
              telemetry.ready = true;
            },
          ),
          fakeStep(
            t,
            'after',
            InitStage.sdkInit,
            onStart: () => seenWhenAfterStarted = telemetry.events.length,
          ),
        ], telemetry: telemetry);
        final outcome = start(init);
        async.elapse(const Duration(seconds: 2));

        expect(outcome(), isA<BootSucceeded>());
        // Nothing reached analytics before it was initialized...
        expect(seenBeforeAnalytics, 0);
        // ...and everything buffered was flushed right after it was.
        expect(seenWhenAfterStarted, 3);
        expect(telemetry.events.map((e) => e.$2['step'] ?? e.$1).toList(), [
          'config_fetch',
          'crash_reporting',
          'analytics',
          'after',
          AnalyticsEvents.appInitCompleted,
        ]);
        final step = telemetry.events.first.$2;
        expect(
          step.keys,
          containsAll(['step', 'stage', 'duration_ms', 'result']),
        );
        expect(step['stage'], 'config');
        final completed = telemetry.events.last.$2;
        expect(completed['cold_start'], isTrue);
        expect(completed['total_ms'], isA<int>());
        expect(init.pendingTelemetry, isEmpty);
      });
    });
  });
}
