# Mobile app (Flutter)

Party music game client. Internal code name `sporand`; the public brand,
bundle ids and domain are still placeholders (brief Q3).

## Run

There is exactly one entry point, `lib/main.dart` (`main()` -> `bootstrap()`).
The flavor and all environment values come from `--dart-define`:

```sh
flutter run                                   # dev, offline fakes, no Firebase
flutter run --dart-define=FLAVOR=staging --dart-define=API_BASE_URL=https://api.<domain>
flutter run --dart-define=FLAVOR=spotifyProto # no ads, no purchases, no paywall
```

| Define | Meaning |
|---|---|
| `FLAVOR` | `dev` (default), `staging`, `prod`, `spotifyProto` |
| `API_BASE_URL` | REST base (`https://api.<domain>`, or `http://localhost:<port>` for a local server); the WebSocket is `wss://…/v1/ws` on the same host. Empty = offline fake auth, and rooms cannot be opened |
| `LINK_HOST` | domain of `https://<domain>/j/{room_code}` join links |
| `FIREBASE_ENABLED` | default `false` for dev, `true` otherwise |
| `REVENUECAT_API_KEY_IOS` / `_ANDROID` | RevenueCat public SDK keys (dev without a key shows a demo paywall) |
| `ADMOB_INTERSTITIAL_*`, `ADMOB_REWARDED_*` | ad units; dev/staging fall back to Google test units, prod never does |
| `STORE_URL_*`, `TERMS_URL`, `PRIVACY_URL` | force-update target and legal links |

Without Firebase config files the app still boots: Firebase-backed services
use in-memory fakes (dev) or degrade to no-ops (other flavors), and the boot
report lists the degraded steps (visible in Settings).

## Boot pipeline (R-BOOT)

`lib/app/bootstrap/`: `AppInitializer` (pure Dart) runs the stages
`config -> warmup -> sdk_init -> enter_app` while `BootSplashPage` shows real,
weighted progress. Steps are declared in `steps/boot_steps.dart`; timings come
from Remote Config (`boot_config_timeout_ms`, `boot_min_splash_ms`,
`boot_max_total_ms`). Deep links that arrive during boot are queued and
opened by the `route` step.

## Realtime, timing and the game

- **REST** (`lib/core/net/api_client.dart`): Bearer auth with a single-flight
  refresh on 401 (`AuthService`), `X-Firebase-AppCheck` on every call
  (limited-use tokens for `/v1/auth/guest`, `/v1/rooms`,
  `/v1/me/entitlements/sync`), `application/problem+json` -> `ApiError.code`.
- **WebSocket** (`lib/core/net/ws_client.dart`): `hello` first with a fresh
  ws-ticket, strictly increasing client `seq`, resume with `hello.last_seq`,
  backoff with jitter, close codes 4401–4503, `server.draining`, a 15 s
  heartbeat watchdog, and `clock.pong` sent before any other processing.
- **Protocol DTOs** (`lib/core/net/protocol/`): hand-written, one class per
  §4.3 message. `test/core/net/protocol_test.dart` checks them against the
  golden fixtures in `packages/protocol/fixtures/ws` when that package is
  checked out. They are replaced by `lib/contracts/` once codegen lands.
- **Clocks** (`lib/core/clock/`): `InputClock` (Pigeon `InputClockApi`),
  `tapMonoUsFromPointer`, the unlock/tap sanity rules in
  `MonoTimestamps`, and `ClockCalibrationRecorder`. The calibration screen
  (`/debug/clock`, Settings -> "Калибровка часов" in non-prod builds) is the
  device test from brief §5/§9: tap it a few times on a real iPhone and
  Android phone and copy the report.
- **Game** (`lib/features/game/`): `GameController` (sealed `GameUiState`)
  unlocks at `start_at_mono_us` or on `round.start`, commits the first
  pointer down (`Listener.onPointerDown`, never `onTap`), and runs the
  end-of-game flow (bonus offer with rewarded SSV, ad break, buffered
  results). The host's playback is driven by `HostPlaybackCoordinator`.
- **Playback** (`lib/core/playback/`): `PlaybackAdapter`; `ClipPlayerAdapter`
  over Pigeon `ClipPlayerApi`; `SpotifyRemotePlaybackAdapter` (spotifyProto,
  native bridge still TODO) with the pure `computeAudioStartFromPlayerState`.

### Native bridges

`packages/sporand_native/` is a local Flutter plugin with the Pigeon host
APIs (`InputClockApi`, `ClipPlayerApi`). It registers itself through
`GeneratedPluginRegistrant`, so neither the Xcode project nor `MainActivity`
needs edits. Regenerate after changing `pigeons/*.dart`:

```sh
dart run pigeon --input pigeons/input_clock.dart
dart run pigeon --input pigeons/clip_player.dart
```

The Swift and Kotlin code has not been compiled in the sandbox that wrote it
(no Xcode or Android SDK); build it once on a Mac and with the Android SDK.

## Layout

- `lib/app/` bootstrap, router, theme, flavors, DI (`di/providers.dart`)
- `lib/core/` SDK interfaces with real adapters and fakes; `net/`, `clock/`,
  `playback/`
- `lib/features/<feature>/{data,domain,presentation}`: onboarding, home,
  lobby (rooms API, room session), game, results, paywall, settings, debug
- `lib/core/l10n/arb/` ARB files (ru template, en, pl); `flutter gen-l10n`
- `lib/contracts/` reserved for code generated from `packages/protocol`
- `pigeons/` Pigeon definitions; `packages/sporand_native/` generated code +
  native implementations

## Checks

```sh
flutter analyze
flutter test
```

## TODO(owner) before a store build

- Firebase: run `flutterfire configure` (adds GoogleService-Info.plist,
  google-services.json and the Google Services Gradle plugin); both files are
  git-ignored.
- AdMob: real app ids (`-PadmobAppId=` for Android, `GADApplicationIdentifier`
  in `ios/Runner/Info.plist`) and ad unit ids.
- RevenueCat public SDK keys; products per brief §4.7.
- Join links: `-PlinkHost=<domain>`, `assetlinks.json`, the iOS Associated
  Domains entitlement and `apple-app-site-association`.
- Brand name, bundle/application ids, store URLs, Terms and Privacy URLs.
- media3 version in `packages/sporand_native/android/build.gradle.kts`
  (not verifiable offline).
- Run the clock calibration screen on one iPhone and one Android phone
  (including after the device slept) and keep the reports.
