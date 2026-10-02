// Wave 8b: the boot pipeline runner is mobile_kit's (mobile-template).
// `app_init_completed` carries `degraded_steps` as a count and
// `degraded_step_ids` (comma-separated) when steps degraded: the one
// intended analytics change of wave 8b.
export 'package:mobile_kit/mobile_kit.dart'
    show AppInitializer, StepErrorHandler, degradedStepIdsParam;
