// Wave 8b: the JSON readers live in mobile_kit (mobile-template); this path
// stays so existing imports keep working (a shim until 8c). `extrasOf` and
// `ExtrasRead` read the project fields the kit DTOs keep in `extras`.
export 'package:mobile_kit/mobile_kit.dart'
    show
        ExtrasRead,
        JsonMap,
        JsonRead,
        ProtocolFormatException,
        WireEnum,
        asInt,
        asObject,
        asString,
        extrasOf,
        parseWire;
