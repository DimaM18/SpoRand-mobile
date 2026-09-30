import 'dart:async';

import 'package:sporand/app/bootstrap/domain/init_context.dart';

/// Loader label shown while a stage runs. The UI maps it to a localized
/// string («Загружаем настройки…», «Готовим звуки…», «Подключаем сервисы…»,
/// «Поехали!»); this layer stays free of Flutter and l10n.
enum BootLabel { loadingConfig, warmingUp, connectingServices, entering }

/// Boot stages, in execution order (R-BOOT; brief §3 "Boot pipeline").
enum InitStage {
  config('config', BootLabel.loadingConfig),
  warmup('warmup', BootLabel.warmingUp),
  sdkInit('sdk_init', BootLabel.connectingServices),
  enterApp('enter_app', BootLabel.entering);

  const InitStage(this.wireName, this.label);

  /// Value of the `stage` analytics parameter.
  final String wireName;
  final BootLabel label;

  /// `sdk_init` runs strictly in declaration order: crash reporting first,
  /// consent before ads, auth before purchases (brief §3). Other stages run
  /// independent steps in parallel.
  bool get isSequential => this == InitStage.sdkInit;
}

/// `app_init_step.result` (brief §4.5).
enum StepResult {
  ok,

  /// The step finished but fell back (cached config, SDK unavailable...).
  degraded,
  failed,
  timeout;

  String get wireName => name;
}

typedef InitStepBody = FutureOr<StepResult?> Function(InitContext context);

/// One unit of boot work.
///
/// A step returns [StepResult.ok] (or null), [StepResult.degraded] when it
/// completed with a fallback, or throws. The initializer applies [timeout],
/// records the result and decides what happens next: a failing [critical]
/// step stops the boot with a retry, anything else degrades and continues.
final class InitStep {
  InitStep({
    required this.id,
    required this.stage,
    required this.timeout,
    required this._body,
    this.critical = false,
    this.weight = 1,
    this.dependsOn = const {},
    this.runsWhenGated = false,
    this._resolveTimeout,
  }) : assert(weight >= 0, 'weight must not be negative');

  /// `app_init_step.step` value.
  final String id;
  final InitStage stage;
  final Duration timeout;
  final bool critical;

  /// Share of the progress bar.
  final double weight;

  /// Steps (same or earlier stage, declared earlier) that must finish first.
  /// Within a parallel stage this is what keeps e.g. `config_fetch` after
  /// `config_activate_cached` while unrelated steps still overlap.
  final Set<String> dependsOn;

  /// Still runs when a force-update/maintenance gate short-circuits the boot
  /// (crash reporting, so the blocked screen still reports crashes).
  final bool runsWhenGated;

  final InitStepBody _body;
  final Duration Function(InitContext context)? _resolveTimeout;

  /// Timeout for this run; may depend on config (`boot_config_timeout_ms`).
  Duration timeoutFor(InitContext context) =>
      _resolveTimeout?.call(context) ?? timeout;

  Future<StepResult?> run(InitContext context) =>
      Future.sync(() => _body(context));

  @override
  String toString() => 'InitStep($id)';
}
