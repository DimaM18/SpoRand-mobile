# sporand_native

Local Flutter plugin with the app's native bridges (internal; not published).

| API | Dart | iOS | Android |
|---|---|---|---|
| `InputClockApi` | `input_clock_api.g.dart` | `ProcessInfo.systemUptime` × 1e6 | `SystemClock.uptimeMillis()` × 1000 |
| `ClipPlayerApi` | `clip_player_api.g.dart` | `AVAudioPlayer.play(atTime:)` | media3 ExoPlayer + `Handler.postAtTime` |

The `*.g.*` files are generated. Edit `apps/mobile/pigeons/*.dart` and run,
from `apps/mobile`:

```sh
dart run pigeon --input pigeons/input_clock.dart
dart run pigeon --input pigeons/clip_player.dart
```

The native code lives in a plugin (not in `Runner`) so that it is registered by
`GeneratedPluginRegistrant` without edits to the Xcode project or `MainActivity`.
It has not been compiled in the sandbox that produced it (no Xcode/Android SDK).
