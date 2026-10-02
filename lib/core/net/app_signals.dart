// Wave 8b: the lifecycle and connectivity signals live in mobile_kit
// (mobile-template); this path stays so existing imports keep working (a
// shim until 8c). Their values are the `app.state` wire values
// (`AppStateSignal` in ws_enums.dart is the kit's `AppSignal`): each one
// makes the server run a clock re-sync burst.
export 'package:mobile_kit/mobile_kit.dart'
    show
        AppSignal,
        AppSignalSource,
        FakeAppSignalSource,
        FlutterAppSignalSource;
