// Wave 8b: the top-level redirect policy is mobile_kit's (mobile-template):
// the splash while booting (links queued for the `route` step), the gate
// screens, the age gate and onboarding first (links deferred until done),
// then home. Its `home` defaults to SpoRand's `Routes.home`.
export 'package:mobile_kit/mobile_kit.dart' show guardRedirect;
