// Wave 8b: the boot step model is mobile_kit's (mobile-template). `InitStep`
// keeps its constructor and adds the `after`/`before` anchors of
// `mergeInitSteps`; `StepResult.skipped` marks a step whose feature is off.
export 'package:mobile_kit/mobile_kit.dart'
    show BootLabel, InitStage, InitStep, InitStepBody, StepResult;
