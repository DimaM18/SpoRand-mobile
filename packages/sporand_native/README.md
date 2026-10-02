# sporand_native

Local Flutter plugin with the app's native bridges (internal; not published).

| API | Dart | iOS | Android |
|---|---|---|---|
| `ClipPlayerApi` | `clip_player_api.g.dart` | `AVAudioPlayer.play(atTime:)` | media3 ExoPlayer + `Handler.postAtTime` |
| `MusicAppApi` | `music_app_api.g.dart` | always `false` (Dart opens the cue's `hint_url`) | `MediaStore.INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH` |

The input clock (`InputClockApi`: `ProcessInfo.systemUptime` × 1e6 on iOS,
`SystemClock.uptimeMillis()` × 1000 on Android) is not in this package since
wave 8b: it is the template plugin `mobile_kit_clock`, registered through its
own pubspec entry and shipping its own privacy manifest (35F9.1). This
package's `PrivacyInfo.xcprivacy` keeps the 35F9.1 entry because
`ClipPlayerHost` reads `systemUptime` too.

Every clock value crossing a bridge is a raw OS input-clock value (`*_os_us`)
on the same base as `mobile_kit_clock`. Native code never knows the process anchor;
the Dart `InputClock` converts before anything reaches the protocol (Apple
required-reason API 35F9.1: raw uptime never leaves the device).

The `*.g.*` files are generated. Edit `apps/mobile/pigeons/*.dart` and run,
from `apps/mobile`:

```sh
dart run pigeon --input pigeons/clip_player.dart
dart run pigeon --input pigeons/music_app.dart
```

`clip_player.dart` generates the one `NativeBridgeError` class of the package
(`includeErrorClass: true`); `music_app.dart` reuses it
(`includeErrorClass: false`). `mobile_kit_clock` generates its own
`MobileKitClockError` in the Kotlin package `io.github.dimam18.mobile_kit_clock`
and the Swift module `mobile_kit_clock`, so the two plugins cannot clash.

The native code lives in a plugin (not in `Runner`) so that it is registered by
`GeneratedPluginRegistrant` without edits to the Xcode project or `MainActivity`.
It compiles: on 2026-09-30 `flutter build ios --simulator --debug` and `flutter build apk --debug`
succeeded on the owner's Mac (Xcode 27.0, Android SDK 36). Runtime behaviour on real devices
(clock calibration, scheduled clip start, the music-app intent) is still unverified.
