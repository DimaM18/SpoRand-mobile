// Wave 8b: the external link launcher lives in mobile_kit (mobile-template);
// this path stays so existing imports keep working (a shim until 8c).
export 'package:mobile_kit/mobile_kit.dart'
    show
        ExternalLinkLauncher,
        FakeExternalLinkLauncher,
        UrlLauncherExternalLinkLauncher;
