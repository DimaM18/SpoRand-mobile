// Wave 8b: the boot controller is mobile_kit's (mobile-template); it runs
// the kit's `appInitializerProvider` with SpoRand's steps
// (`bootStepsProvider`, see app/di/providers.dart).
export 'package:mobile_kit/mobile_kit.dart'
    show BootController, bootControllerProvider;
