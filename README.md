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
| `ROOM_PROVIDER` | provider new rooms request (QA); default `test_catalog` in dev, `external_player` in staging/prod, `spotify_app_remote` in spotifyProto. The server may fall back to its `default_provider` (addendum A2.5) |

Without Firebase config files the app still boots: Firebase-backed services
use in-memory fakes (dev) or degrade to no-ops (other flavors), and the boot
report lists the degraded steps (visible in Settings).

## Boot pipeline (R-BOOT)

`lib/app/bootstrap/`: `AppInitializer` (pure Dart) runs the stages
`config -> warmup -> sdk_init -> enter_app` while `BootSplashPage` shows real,
weighted progress. Steps are declared in `steps/boot_steps.dart`; timings come
from Remote Config (`boot_config_timeout_ms`, `boot_min_splash_ms`,
`boot_max_total_ms`). Deep links that arrive during boot are queued and
opened by the `route` step. The `boot_min_splash_ms` hold happens before
`enter_app`, so a link received while the splash is held is not lost.

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
  §4.3 message (`ws_messages.dart`) and per REST body the app uses
  (`rest_models.dart`). Client-to-server payloads and request bodies parse
  strictly (unknown fields, nulls and negative `*_mono_us` are errors), so
  the in-memory test server catches a bad frame the app sends.
  `round.prepare` enforces the protocol's cross-field rules (clip xor cue,
  text rounds). `test/core/net/contract_fixtures_test.dart` round-trips
  **every** fixture of `packages/protocol/fixtures` (ws goldens, variants,
  invalid frames, REST) through them, or requires the fixture to be listed
  with the reason the app does not consume it. They are replaced by
  `lib/contracts/` once codegen lands.
- **Clocks** (`lib/core/clock/`): `InputClock` holds the **process anchor**
  (brief §5): every `*_mono_us` on the wire is OS input-clock time minus
  `anchor_us`, read once in `bootstrap()`, so raw uptime never leaves the
  device (Apple required-reason 35F9.1). Pointer and frame timestamps go
  through `InputClock.fromOs` (`tapMonoUsFromPointer`, `currentFrameMonoUs`),
  native stamps through `fromOsUs`, and only the clip player's schedule back
  through `toOsUs`. The raw source is `InputClockSource` (Pigeon
  `InputClockApi`). Also: the unlock/tap sanity rules in `MonoTimestamps`
  and `ClockCalibrationRecorder`. The calibration screen (`/debug/clock`,
  Settings -> "Калибровка часов" in non-prod builds) is the device test from
  brief §5/§9: tap it a few times on a real iPhone and Android phone and
  copy the report.
- **Game** (`lib/features/game/`): `GameController` (sealed `GameUiState`)
  unlocks scheduled and text rounds at `start_at_server_ms` converted with
  the latest `clock.result` offset (the server's `start_at_mono_us` only
  before the first result; a newer result moves a pending unlock), and
  host-reported rounds on `round.start`. It commits the first pointer down
  (`Listener.onPointerDown`, never `onTap`) and runs the end-of-game flow
  (bonus offer with rewarded SSV, ad break, buffered results). The host's
  clip playback is driven by `HostPlaybackCoordinator`.
- **BYOP / `external_player`** (addendum A2.2): the app never plays the
  song. The DJ (the host, the device that gets `round.prepare.cue`) sees
  «Включи эту песню в своём музыкальном приложении», can hand the song to
  their music app (`MusicAppLauncher`: Android play-from-search intent, iOS
  the cue's `hint_url`), and taps «Музыка играет!»: its pointer-down time is
  `round.playback_started{source: dj_tap}` (checked like an answer tap: a
  pointer time outside [cue arrival, now] falls back to the input clock).
  Guests see «Ведущий включает
  песню…» until `round.start`. In guess_track the DJ gets no answer buttons
  unless `guess_track_dj_can_answer`. Text rounds (provider `none`) show the
  question and options without audio UI. Nothing shows artwork or logos.
- **«Мои песни»** (`lib/features/my_songs/`, route `/my-songs`, A2.3):
  debounced `GET /v1/songs/search`, 5–10 picks saved with `PUT /v1/me/picks`,
  and «Что увидят друзья». In the lobby, «Добавить мои песни» sends the pool
  with `PUT /v1/rooms/{room_id}/pool` only after the consent «Эти песни будут
  показаны комнате как ваши»; the host's start stays disabled until the
  pools meet `pool_min_tracks_per_contributor` and the mode's minimums.
- **Playback** (`lib/core/playback/`): `PlaybackAdapter`; `ClipPlayerAdapter`
  over Pigeon `ClipPlayerApi`; `NoAudioPlaybackAdapter` for
  `external_player` / `none`; `SpotifyRemotePlaybackAdapter` (spotifyProto,
  frozen, native bridge still TODO) with the pure
  `computeAudioStartFromPlayerState`.
- **Purchases**: before a purchase or restore, `ensurePurchasesUser` logs
  RevenueCat in as our `user_id` if the boot `purchases` step could not.

### Native bridges

`packages/sporand_native/` is a local Flutter plugin with the Pigeon host
APIs (`InputClockApi`, `ClipPlayerApi`, `MusicAppApi`). Clock values crossing
a bridge are raw OS time (`*_os_us`); only the Dart `InputClock` knows the
anchor. It registers itself through
`GeneratedPluginRegistrant`, so neither the Xcode project nor `MainActivity`
needs edits. Regenerate after changing `pigeons/*.dart`:

```sh
dart run pigeon --input pigeons/input_clock.dart
dart run pigeon --input pigeons/clip_player.dart
dart run pigeon --input pigeons/music_app.dart
```

The Swift and Kotlin code has not been compiled in the sandbox that wrote it
(no Xcode or Android SDK); build it once on a Mac and with the Android SDK.

## Layout

- `lib/app/` bootstrap, router, theme, flavors, DI (`di/providers.dart`)
- `lib/core/` SDK interfaces with real adapters and fakes; `net/`, `clock/`,
  `playback/`
- `lib/features/<feature>/{data,domain,presentation}`: onboarding, home,
  lobby (rooms API, room session), my_songs, game, results, paywall,
  settings, debug
- `lib/core/l10n/arb/` ARB files (ru template, en, pl); `flutter gen-l10n`
- `lib/contracts/` reserved for code generated from `packages/protocol`
- `pigeons/` Pigeon definitions; `packages/sporand_native/` generated code +
  native implementations

## Checks

```sh
flutter analyze
flutter test
```

## End-to-end suite (`test_e2e/`)

`scripts/e2e.sh` (repository root) builds the pnpm workspace, starts
`apps/server` on a free port (`PORT=0` + `PORT_FILE`) with short timings, a
memory analytics sink, the seed song source and `APP_CHECK_MODE=off`, then
runs `flutter test test_e2e --dart-define=API_BASE_URL=http://127.0.0.1:<port>`
one file at a time and stops the server. Server error log lines also fail it.
Without `API_BASE_URL` (or `E2E_API_BASE_URL`) the suites skip, so a plain
`flutter test` never needs a server.

- **What is real.** Each simulated phone (`support/e2e_phone.dart`) is a
  `ProviderContainer` with the app's own wiring: `ApiClient`, `AuthService`,
  `HttpRoomsApi`, `HttpMySongsApi`, `WsClient` over a real WebSocket, the
  protocol DTOs and the controllers the screens use (`ActiveRoomController`,
  `LobbyController`, `GameController`). Only device-bound pieces are fakes:
  the OS input clock (`support/phone_clock.dart`: real time on a per-phone
  base hours to weeks apart), storage, App Check (no token), ads, purchases,
  analytics and the music-app launcher. The tests do what the widgets would,
  e.g. `GameController.tap` with the pointer time from the phone's clock.
- **Network.** `flutter test` does not mock HTTP, but
  `TestWidgetsFlutterBinding` does (every request and WebSocket upgrade gets
  400). The suites use plain `test()`, never `testWidgets` or the widgets
  binding, and `requireRealNetwork()` fails fast if `HttpOverrides` are
  installed. `support/wire_tap.dart` records every frame and can delay an
  outgoing frame (later frames queue behind it, as on one TCP stream) or
  lose incoming frames and drop the socket; `support/rest_tap.dart` records
  every REST exchange.
- **Contract audit.** Every server frame must decode with the Dart DTOs, not
  be an unknown type and re-encode to the same JSON (modulo omitted nulls);
  every client frame must parse with the strict client DTOs with strictly
  increasing `seq`; every REST request and response must round-trip through
  its DTO.
- **Scenarios.** `byop_game_test.dart` (whose_song, external_player: cue to
  the DJ only, `dj_tap`, tap times by device clock with an answer delayed on
  the wire, bonus request without App Check token, ad break, results),
  `byop_guess_track_test.dart` (start timeout → `round.voided` → spare,
  `dj_ineligible`), `text_round_game_test.dart` (provider none, local unlock
  at `start_at`, lobby settings, ready, kick with 4403, play again),
  `reconnect_resume_test.dart` (`app.state` re-sync, lost frames and socket,
  resume with `hello.last_seq`).

```sh
scripts/e2e.sh                                          # from the repo root
SKIP_BUILD=1 E2E_TESTS=test_e2e/byop_game_test.dart scripts/e2e.sh
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

## CI

`.github/workflows/e2e.yml` runs `scripts/e2e.sh` (Node 22, pnpm, Flutter
3.47.5) when the server, the packages or the app change.

`.github/workflows/mobile.yml` runs on pushes and pull requests that touch
`apps/mobile/`: Flutter 3.47.5, `flutter pub get`, `flutter analyze
--no-fatal-infos` (errors and warnings fail; infos are reported) and
`flutter test --coverage` (the lcov report is uploaded as an artifact).
