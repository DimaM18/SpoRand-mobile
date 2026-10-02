// Wave 8b: the age band sync (`PATCH /v1/me {age_band}`) lives in mobile_kit
// (mobile-template); this path stays so existing imports keep working (a
// shim until 8c). The server reads the band when a player creates or joins
// a room, so `ActiveRoomController` calls `ensureSynced` right before both.
export 'package:mobile_kit/mobile_kit.dart' show AgeBandSync;
