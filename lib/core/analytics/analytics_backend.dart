// Wave 8b: the analytics backends live in mobile_kit (mobile-template); this
// path stays so existing imports keep working (a shim until 8c).
export 'package:mobile_kit/mobile_kit.dart'
    show
        AnalyticsBackend,
        AnalyticsConsentSignals,
        InMemoryAnalyticsBackend,
        RecordedEvent;
