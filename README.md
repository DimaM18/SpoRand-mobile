# Mobile app (Flutter)

Party music game client. Internal code name `sporand`; the public brand,
bundle ids and domain are still placeholders (owner question Q3, `docs/DEVELOPMENT.md` §12).

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
| `ROOM_PROVIDER` | provider new rooms request (QA); default `test_catalog` in dev, `youtube_embed` in staging/prod (wave 4), `spotify_app_remote` in spotifyProto. The server may fall back to its `default_provider` (addendum A2.5) |
| `APP_BUNDLE_ID` | iOS bundle id / Android application id (default: the placeholder `dev.brandtbd.sporand`); the embedded YouTube player identifies the app as `https://<bundle id>` |

Without Firebase config files the app still boots: Firebase-backed services
use in-memory fakes (dev) or degrade to no-ops (other flavors), and the boot
report lists the degraded steps (visible in Settings).

## Boot pipeline (R-BOOT)

`lib/app/bootstrap/` (since wave 8b mobile_kit's runner and kit steps, see
"mobile_kit (wave 8b, step 7.2: app layer)"): `AppInitializer` (pure Dart) runs the stages
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
  WS message (`ws_messages.dart`) and per REST body the app uses
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
  (`docs/DEVELOPMENT.md` §5): every `*_mono_us` on the wire is OS input-clock time minus
  `anchor_us`, read once before the boot (`inputClockPreBootHook`), so raw uptime never leaves the
  device (Apple required-reason 35F9.1). Pointer and frame timestamps go
  through `InputClock.fromOs` (`tapMonoUsFromPointer`, `currentFrameMonoUs`),
  native stamps through `fromOsUs`, and only the clip player's schedule back
  through `toOsUs`. The raw source is `InputClockSource` (Pigeon
  `InputClockApi`). Also: the unlock/tap sanity rules in `MonoTimestamps`
  and `ClockCalibrationRecorder`. The calibration screen (`/debug/clock`,
  Settings -> "Калибровка часов" in non-prod builds) is the device calibration test
  (`docs/DEVELOPMENT.md` §12): tap it a few times on a real iPhone and Android phone and
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
  song. The round's DJ is whoever `round.prepare.you_are_dj` names (the
  host, or with `byop_dj_rotation` any player who opted in with «Могу
  включать музыку» / `lobby.set_can_dj`; never derived from
  `is_playback_device`). The DJ sees «Включи эту песню в своём музыкальном
  приложении», can hand the song to their music app (`MusicAppLauncher`:
  Android play-from-search intent, iOS the cue's `hint_url`), and taps
  «Музыка играет!»: its pointer-down time is
  `round.playback_started{source: dj_tap}` (checked like an answer tap: a
  pointer time outside [cue arrival, now] falls back to the input clock).
  Everyone else sees «<имя DJ> включает песню…» (`dj_player_id`) until
  `round.start`. The DJ gets no answer buttons unless the mode's key allows
  it (`whose_song_dj_can_answer`, `guess_track_dj_can_answer`, both false by
  default): «Ты DJ этого раунда — отвечают остальные». The lobby shows the
  toggle and a DJ badge per opted-in player. Text rounds (provider `none`)
  show the question and options without audio UI. Nothing shows artwork or
  logos.
- **Emoji quiz** (`emoji_quiz`, wave 3) [новое имя — согласовать]: no audio
  at all. `round.prepare` carries `emoji_prompt` (2–6 emoji, re-checked by
  `core/net/protocol/emoji_text.dart`); the emoji stay behind «?» tiles until
  the round opens at `start_at` for everyone, then pop in (`EmojiPuzzle`;
  instant with reduced motion). Answers use the same `Listener` timing path
  as every round; the host answers too (no DJ, no owner). The reveal shows
  title, artist and `year`. The lobby host picks the catalogue markets
  (Международные / Польские; there is no Russian/CIS market) and the max
  difficulty; emoji rooms need 2 players and no pools. The catalogue itself
  never reaches the app.
- **YouTube / `youtube_embed`** (wave 4) [новое имя — согласовать]: the
  round's DJ plays the song in the **official** embedded YouTube player
  (`lib/core/playback/youtube/`: `YouTubePlayerFactory` /
  `YouTubeEmbedPlayer`, real `IframeYouTubePlayerFactory` over
  `youtube_player_iframe` 6.0.2, `FakeYouTubePlayerFactory` in tests: no
  WebView in `flutter test`). Everyone else sees «<имя> включает песню…» as
  in BYOP. Rules the code keeps (YouTube API Services policies, checked
  2026-09-30):
  - the player (`DjVideoSlot` / `YouTubeRoundPlayer`) is full width at 16:9,
    pinned above the round's scrolling content, fully visible, with nothing
    drawn over it (the void notice moves below it); the DJ presses play in
    the player (no autoplay); «Музыка играет!» (`DjMusicPlayingButton`,
    `Listener.onPointerDown` + `InputClock`, `source: dj_tap`) sits **below**
    it. Pre-roll ads are never blocked or skipped; player states are logged
    in debug builds only, never used for timing;
  - the wrapper renders the package's WebView itself instead of the
    package's `YoutubePlayer` widget (that one paints a Flutter thumbnail
    over the player while loading and lifts the WebView into an app-wide
    overlay), passes `origin` / `widget_referrer` and the WebView base URL
    `https://<bundle id>` (a missing identity is error 153), and forwards
    raw `onError` codes through an extra JavaScript channel because the
    package reports 153 as `unknown(-1)`;
  - on an error the controller sends `round.playback_failed{reason, code,
    video_id}` and tries `fallback_video_ids` in order, then shows the BYOP
    cue card (`DjVideoCueFallback`). Screens narrower than 356 dp (the
    YouTube 200 px floor at 16:9) get the cue without a report;
  - the player is disposed in the frame the round leaves play (reveal,
    void, pause, ad break) and whenever the app goes to the background
    (recreated on resume); ads and results never share a screen with it;
  - consent (`YouTubeConsentGate`, `requires_consent_before_load`): outside
    the EEA/UK (UMP `notRequired`) the player loads; otherwise the DJ sees a
    short consent sheet first. «Разрешить» is stored
    (`youtube_player_consent`); «Нет, включу вручную» sends
    `playback_failed{consent_declined}` and shows the cue, and is not asked
    again in this app session;
  - analytics drop `video` / `youtube` parameter names and YouTube-looking
    values (`AnalyticsService.isYouTubeContentValue`, as in the protocol).
  - Deviation: `youtube_player_min_width_dp` (default 480) is the target
    width, but portrait phones are 360–430 dp wide, so the player takes the
    full width whenever it clears the 356 dp floor (owner question).
- **Modes** (wave 4): the picker (create-room sheet, lobby) shows only
  `modes_enabled` (the room's frozen config in the lobby, Remote Config
  before a room exists; default whose_song and emoji_quiz). The UI calls
  `emoji_quiz` «Угадай песню»; `guess_track` («Угадай трек») stays in code,
  hidden unless enabled.
- **Voided rounds**: «Раунд пропущен: <причина>» stays over the spare round
  until `void_notice_ms` (room config) after `round.voided`; it ignores
  pointers and does not delay the spare.
- **«Мои песни»** (`lib/features/my_songs/`, route `/my-songs`, A2.3):
  debounced `GET /v1/songs/search`, 5–10 picks saved with `PUT /v1/me/picks`,
  and «Что увидят друзья». Wave 4: «Видео YouTube» on a picked song pastes
  a link (clipboard; the link is picked out of shared text), resolves it
  with `POST /v1/songs/youtube/resolve` and shows title and channel as text
  only (never a thumbnail); saving sends `song_picks` with
  `youtube_video_id` (plain `song_ids` while no song has a video), and the
  lobby pool carries the video id. Title and channel stay in memory only.
  No share-extension target yet. In the lobby, «Добавить мои песни» sends the pool
  with `PUT /v1/rooms/{room_id}/pool` only after the consent «Эти песни будут
  показаны комнате как твои»; the host's start stays disabled until the
  pools meet `pool_min_tracks_per_contributor` and the mode's minimums.
- **Playback** (`lib/core/playback/`): `PlaybackAdapter`; `ClipPlayerAdapter`
  over Pigeon `ClipPlayerApi`; `NoAudioPlaybackAdapter` for
  `external_player` / `none`; `SpotifyRemotePlaybackAdapter` (spotifyProto,
  frozen, native bridge still TODO) with the pure
  `computeAudioStartFromPlayerState`.
- **Ads**: the interstitial follows the server's per-player
  `game.ad_break.show_interstitial` (the server leaves out, e.g., the BYOP
  DJ whose music app may still play) and is never shown while this device's
  own `PlaybackAdapter.isPlaying`.
- **Consent and analytics identity**: `ConsentSync` sends
  `PUT /v1/me/consent` after the onboarding consent (`source: onboarding`),
  every Settings toggle (`settings`) and UMP changes (`ump`): debounced,
  retried once, never blocking the UI. `AnalyticsIdentity` sets the GA4 user
  id to the session's `analytics_uid` (auth responses; `GET /v1/me` for a
  session stored without one), only while analytics consent is granted, and
  clears it when the session is cleared (`AuthService.signOut`: logout or
  the local half of an account deletion).
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

- `lib/app/` bootstrap, router, flavors, DI (`di/providers.dart`);
  `app/theme/*.dart` are re-export shims for `lib/core/theme/`
- `lib/core/` SDK interfaces with real adapters and fakes; `net/`, `clock/`,
  `playback/`; `theme/` (tokens, `AppTheme`, fonts) and `ui/` (shared
  components), see "Design system (wave 6)"
- `assets/fonts/` bundled OFL fonts with their licence texts
- `lib/features/<feature>/{data,domain,presentation}`: onboarding, home,
  lobby (rooms API, room session), my_songs, game, results, paywall,
  settings, debug
- `lib/core/l10n/arb/` ARB files (ru template, en, pl); `flutter gen-l10n`.
  ru/pl copy addresses the player with informal singular «ты»/«ty»,
  gender-neutral (no gendered past tense or short adjectives)
- `lib/contracts/` reserved for code generated from `packages/protocol`
- `pigeons/` Pigeon definitions; `packages/sporand_native/` generated code +
  native implementations

## mobile_kit (wave 8b, step 7.1: foundation and services)

The base of `lib/core/` comes from the template packages `mobile_kit` and
`mobile_kit_clock` (mobile-template, `docs/MIGRATION-SPORAND.md` §5.4). The
old paths stay, so no import changes:

- **Shims** (`export 'package:mobile_kit/…' show …`): `core/{ads,auth,crash,
  firebase,links,platform,privacy,purchases,security}/**`,
  `core/consent/{consent_service,ump_consent_service,consent_policy,
  consent_sync}.dart`, `core/analytics/{analytics_backend,
  firebase_analytics_backend,analytics_identity}.dart`,
  `core/remote_config/*_backend.dart`, `core/net/{api_client,app_signals}.dart`,
  `core/net/protocol/json_read.dart`, `core/clock/*`,
  `core/ui/{timed_tap_target,reduce_motion_scope}.dart` and
  `features/debug/**` (`mobile_kit_clock`). `app/di/providers.dart`
  re-exports `mobile_kit_clock`'s `inputClockProvider` (one clock, one
  anchor). `AppStateSignal` (`ws_enums.dart`) is the kit's `AppSignal`.
- **Typedefs and forwarders** (pixel-identical: the themes carry the kit's
  `KitBrand`/`KitShape` with the «Neon Night+» values): `PartyButton`,
  `PartyCard`/`PartyCardTone`, `PartyChip`, `StatusChip`, `PartyBanner`/
  `PartyBannerTone`, `PartyActionBar`; `showPartyToast` -> `KitToast.show`,
  `showPartySheet` -> `KitSheet.show`. `ui.dart` = the kit components (also
  under their kit names) + the game UI.
- **Adapters** (subclasses with the old constructors): `AnalyticsService`
  (`sporandContentGuard`; the static `isAllowedParamName`, `sanitizeParams`,
  `isYouTubeContentValue`), `RemoteConfigService` (`keys: RcKeys.all`; the
  game getters also as `extension SporandConfig` on the kit's class),
  `UserPrefsRepository` (`KitUserPrefs` + the display name, also as
  `extension SporandPrefs`), `SharedPreferencesStore` (the kit's store with
  `PrefKeys.all`), `PartyLoader` (`KitLoader` with the equalizer).
- **Composed:** `AnalyticsEvents`/`AnalyticsParams`/`AnalyticsUserProperties`,
  `RcKeys`, `PrefKeys` = the kit's constants + the game's;
  `rest_models.dart` re-exports the kit's shared DTOs, which keep
  `games_completed` and `music_links` in `extras` (read as
  `UserProfile.gamesCompleted`, `MeResponse.musicLinks`); `TapTargets` and
  `Motion` = the kit's values + the answer tiles and splash loops;
  `Spacing`, `Radii`, `IconSizes` are the kit's.
- **Stays SpoRand's:** `AppTheme` (the full `ThemeData` builder, plus
  `KitBrand`/`KitShape`), `AppFonts`, `game_colors.dart`, the game widgets,
  `core/consent/youtube_consent.dart`, `core/playback/**`, `core/share/**`,
  the WebSocket client, clock sync and the WS DTOs.
- **Strings:** the kit's screens read `MobileKitLocalizations`;
  `SporandKitStrings` (`core/l10n/kit_strings.dart`) keeps SpoRand's copy of
  the 9 keys whose kit text differs (8 in Polish), taken from the app's ARB.
  `commonLoading` and the `debugClock*` keys left the app's ARB (the kit's
  and `mobile_kit_clock`'s have the same texts).
- **Behaviour notes:** the content guard compares name words (`_` segments
  and camelCase parts, like the server) instead of substrings, and drops
  Spotify references in values too (`spotify_ref`, packages/protocol);
  `paywall_variant` longer than 64 characters falls back to the default
  (the registry's `max_length`); RevenueCat packages report the catalogue
  product id; the calibration page marks a pass with `colorScheme.primary`.
- **New names** «[новое имя — согласовать]»: `sporandContentGuard`,
  `sporandThemeSpec`, `PartyColors.kitBrand`, `SporandKitStrings`
  (`SporandKitStringsRu`/`En`/`Pl`), `sporandKitStrings`, `SporandConfig`,
  `SporandPrefs`, `SporandUserProfile`, `SporandMeResponse`,
  `SharedPreferencesStore.allowList`.

## mobile_kit (wave 8b, step 7.2: app layer)

`bootstrap()` is `runKitApp(sporandAppConfig)` and `SporandApp` is
`KitApp(config: sporandAppConfig)` (mobile-template,
`docs/MIGRATION-SPORAND.md` §5.4). `main()` is unchanged.

- **Config** (`app/bootstrap/bootstrap.dart`): title, `sporandThemeSpec`, the
  full `AppTheme` through `themeBuilder`, `sporandContentGuard`, the
  `AppLocalizations` and `MobileKitClockLocalizations` delegates,
  `KitStringsDelegate(sporandKitStrings)`, `Flavor.registry`,
  `sporandFeatures` (all on), `inputClockPreBootHook` (a failure is recorded
  as `pre-boot hook 0`), and the overrides: `sporandKitOverrides` plus
  SpoRand's own `FlutterResourceWarmer`.
- **Shims:** `application/boot_controller.dart`,
  `domain/{app_initializer,boot_models,boot_telemetry,init_step,version_gate}.dart`,
  `warmup/resource_warmer.dart`, `presentation/boot_labels.dart`,
  `presentation/widgets/boot_status_view.dart`, `MaintenancePage` and
  `maintenanceLiftedProvider` (`gate_pages.dart`), `router/route_guard.dart`,
  `widgets/placeholder_page.dart`. `app/di/providers.dart` re-exports the kit
  providers (and `SporandEnv`, `SporandConfig`, `SporandPrefs`) and keeps the
  game ones.
- **Adapters:** `Flavor` (a `FlavorSpec` subclass with static constants,
  `values`, `registry`, `parse`; spotifyProto: no monetization, its config
  defaults), `AppEnv` (the kit's env under the old const constructor,
  `roomProvider` and `bundleId` default included; the game getters are
  `extension SporandEnv` on the kit's env, which `runKitApp` builds),
  `BootDependencies` (old constructor; `playback`/`realtime` go to the kit
  as `SporandBootServices`), `DeepLinkParser` (the kit's parser with
  `sporandLinkMatchers`, static `normalizeRoomCode`), `PaywallPlacement`
  (an extension type over the wire string).
- **Composition:** `buildBootSteps()` = the kit steps with `music_provider`
  and `realtime` after `ads` (`mergeInitSteps`; same 21 steps in the same
  order). The `ads` step stays SpoRand's: the kit's step reports missing ad
  unit ids as degraded, which SpoRand never did. Game routes go to
  `projectRoutesProvider` (`sporandRoutes()`); `routerProvider` is the
  kit's `kitRouterProvider`, whose guard reads the preferences, so the
  onboarding controller reloads `onboardingStatusProvider` after it writes
  them.
- **Replaced through `kitPagesProvider`** (`sporandKitPages`): the splash
  (`BootSplashPage`; `sporandSplashVisual` gives the kit's status screens the
  two-glow backdrop), onboarding (age gate, consent, blocked), settings
  (calibration tile still `kDebugMode || env.flavor != Flavor.prod`), the
  paywall (perks and placements from `sporandPaywallConfig`) and force
  update. Maintenance is the kit's screen (same texts and icon).
- **Intended change:** `app_init_completed.degraded_steps` is a count again,
  `degraded_step_ids` lists them (two named test edits).
- **Kit behaviour now in the app:** `API_BASE_URL` must be https outside a
  dev flavor on a local host; a missing ad unit falls back to Google's test
  unit per format outside prod, and one configured format loads on its own;
  a link with an invalid `room_code` in a push falls through to its `link`
  key; the «not found» page is the kit's.
- **Drift:** `test/app/client_registry_test.dart` checks the config's content
  guard, the boot steps, features, paywall placements and products against
  `packages/protocol/generated/client-registry.json`. Config keys are not
  compared: the registry lists `youtube_embed_enabled`, which `RcKeys` does
  not (18 keys), and the order differs.
- **New names** «[новое имя — согласовать]»: `sporandAppConfig`,
  `sporandKitOverrides`, `sporandFeatures`, `sporandInitSteps`,
  `SporandBootServices`, `SporandBootDependencies`, `SporandEnv`
  (`appBundleId`), `Flavor.registry`, `sporandRoutes`, `sporandKitPages`,
  `sporandSplashVisual`, `sporandPaywallConfig`, `JoinRoomLinkMatcher`,
  `sporandLinkMatchers`.

## Design system (wave 6, "Neon Night+")

Dark-first neon party look, light and dark themes, WCAG AA. Tokens and the
theme live in `lib/core/theme/`; the old `lib/app/theme/{tokens,app_theme}.dart`
paths re-export them, and `app/bootstrap/presentation/widgets/equalizer_bars.dart`
re-exports `core/ui/equalizer_bars.dart`, so existing imports keep working.

- **Colours.** `ColorScheme`s unchanged except the dark `outline`, raised
  from `#6D6594` to `#7C74A2` in fix round 1 so text-field edges, the off
  switch and step pills reach 3:1 on every container (WCAG 1.4.11; the
  unselected switch thumb is `onSurfaceVariant`, filled text fields have a
  1 dp `outline` edge). `PartyColors` now splits
  `neonGradient` (decorative only; `gradient` stays as its old name) from the
  text-safe `ctaGradient` + `onCta` and `headlineGradient` (ShaderMask text
  of 24 sp or more, once per screen). `GameColors` (ThemeExtension): six
  answer slots (`answers`/`onAnswers`/`answerTonals`, `answer(i)`),
  `correct`/`wrong` pairs, `gold`, `timerUrgent`, `gained`. Every pair is
  recomputed by `test/core/theme/contrast_test.dart` (text >= 4.5, non-text
  >= 3, both themes). Widgets use `colorScheme`, `PartyColors.of`,
  `GameColors.of`; never `Color(0x…)`, `Colors.white` or `BrandColors`.
- **Type.** `AppTheme.textTheme`: Unbounded for short display strings
  (display*, headlineLarge/Medium), Nunito for the rest (answer tiles 22/800,
  buttons 18/800). Weights come from `fontWeight` only: it drives the
  variable `wght` axis (dart:ui docs; `fonts_test.dart` checks widths grow
  at 400/500/700/900 in `flutter_tester`), and an explicit `fontVariations`
  would ignore `copyWith(fontWeight:)`. Tabular figures: `style.tabular`
  (`PartyTextStyles`); Nunito's digits are tabular by default, Unbounded has
  `tnum`.
- **Tokens.** `Spacing` (+ `gutter(width)`), `Radii`, `IconSizes`
  (20/24/32/48), `TapTargets` (48 / 56 / hero 64 / answer 88, 76 below
  700 dp of height), `Motion` (`press` 90 ms, `medium` now 280 ms,
  `stagger` 40 ms, `reducedCrossfade`, `Motion.reduced(context)`).
- **Components** (`lib/core/ui/`, barrel `ui.dart`):
  - `TimedTapTarget`: the only timed input path (`Listener.onPointerDown`
    -> `tapMonoUsFromPointer` + `Semantics(onTap: commit(null))`; up/cancel
    only clear the pressed look; enabled switches instantly).
  - `AnswerTile` (`AnswerTileMode` locked/open/picked/faded/correct/wrong,
    `AnswerMarker` + `AnswerShape` circle/triangle/square/diamond/hexagon/
    star with letters A–F), `TimedCtaButton` (the DJ «Музыка играет!» look,
    with a tonal done state). `AnswerButton` in
    `features/game/.../answer_grid.dart` can delegate its look to
    `AnswerTile` while keeping its unlock callback and `answer-*` keys.
  - `PartyButton` (hero CTA; while `loading` screen readers hear
    «Загрузка…» as a live value), `PartyCard` (`PartyCardTone` surface/
    raised/cta), `GradientHeadline` (the shader hugs the longest line, so a
    wrapped headline reaches every stop), `PartyChip`, `StatusChip`,
    `PlayerAvatar` (`PlayerBadge`; a neutral monogram disc, never an answer
    colour: in «Чья песня?» the answers are the players), `AnswerTimerRing`
    (visual only; real time even when the platform removes animations),
    `ResultPill` (`ResultKind`), `PointsGained`, `StreakChip`,
    `CelebrationBurst`, `PartyBanner` (`PartyBannerTone`), `showPartyToast`,
    `showPartySheet`, `PartyLoader`, `InlineSpinner`, `SkeletonRow`,
    `EqualizerBars`, `PartyActionBar` (the bottom bar of the lobby and the
    results: `surfaceContainer` band with a hairline top edge),
    `ReduceMotionScope`.
  - `AnswerTile` never truncates a label (decoys differ in the last
    letters): «Title — Artist» labels show the title and the artist on two
    fixed lines (`AnswerTile.splitLabel`, display only; screen readers get
    the full label), and the text scale is capped at 1.5x
    (`AnswerTile.maxTextScale`). The state word («Твой ответ», «Верно»,
    «Мимо») is the semantics value; reveal recap tiles are static
    information, not disabled buttons.
  - Reduce-motion: `Motion.reduced` is Android «Remove animations»
    (`MediaQuery.disableAnimations`) or iOS «Reduce Motion»
    (`AccessibilityFeatures.reduceMotion`, which Flutter does not fold in);
    `ReduceMotionScope` in `SporandApp` folds the iOS flag into the
    `MediaQuery` and rebuilds on changes. Press keeps the overlay and drops
    the scale; count-up, scale-in and the celebration are skipped; the timer
    ring steps per second on a timer; loaders freeze; the game-start
    countdown still counts (plain text, one-shot timers).
  - Never on or around the YouTube player: toasts, sheets, glow, the timer
    ring, the celebration, looping loaders, dialogs (the game screen's
    «Выйти» confirms inline in the app bar: «Остаться» / «Выйти из игры?»,
    48 dp targets at any text scale, no time limit, focus on «Остаться»).
  - YouTube DJ layout (`RoundScreen.playerLayoutFor`): portrait puts the
    player on top edge to edge; landscape puts it beside a side pane
    (`landscapePaneMinWidth` 280 dp when there is room, never under
    `landscapePaneFloorWidth` 200 dp) as wide as the height allows and never
    under the 356 dp floor. Rotation and resizing keep the same widget tree,
    so the playing video survives. A window too small for a legal player
    (split screen) shows the cue with «Окно слишком маленькое…» until it
    grows; that is no longer a terminal `DjVideoCueFallback`. The play hint
    under the player draws the play symbol as a Material icon
    (`YouTubePressPlayNote`), never the ▶ character (no bundled font has it;
    the platform fallback draws a colour emoji).
  - Large text: the round question and the status line cap at 1.5x, the
    emoji slots grow with the text scale and the row scales down to the
    card, so the four answers stay on screen at 2.0x on a 390x844 phone.
- **Fonts** (dev-time fetch only; never downloaded at runtime, no
  `google_fonts`): `github.com/google/fonts` rev
  `038b637da7b3fd956a4ed93ffc607c3d5e4ce172`, unsubsetted.

  | File | Source | SHA-256 |
  |---|---|---|
  | `assets/fonts/unbounded/Unbounded[wght].ttf` (778 272 B, wght 200–900) | `ofl/unbounded/` | `323b511be380c8d474ef030686b71aedde501f8d9cd46da558b7c40454372c3f` |
  | `assets/fonts/unbounded/OFL.txt` | `ofl/unbounded/` | `31e5d4e83955e7103c34570dd49b0570ef490800bd65b42923c0dd02445263b3` |
  | `assets/fonts/nunito/Nunito[wght].ttf` (276 932 B, wght 200–1000) | `ofl/nunito/` | `bb55a5ca5c2042335b3991af27c4d0705d0ef41cac6164ac737fd8f2a1e85207` |
  | `assets/fonts/nunito/OFL.txt` | `ofl/nunito/` | `580df76c95a1ec5ab878ceb25bb3d85c6a076804e9c970c8c6972aea775fdf65` |

  Coverage of «Чья это песня? ё й Ё Й — ąćęłńóśźż ĄĆĘŁŃÓŚŹŻ 0123456789 ×»
  checked with fontTools and in `fonts_test.dart`. The licences are
  registered with `LicenseRegistry` by `AppFonts.registerLicenses()` at the
  start of the existing `fonts` warm-up step
  (`FlutterResourceWarmer.loadFonts`), before any await; `showLicensePage`
  lists them. Rendering on real devices is «[не проверено]».
- **New names** «[новое имя — согласовать]»: `GameColors`, `AnswerSwatch`,
  `PartyColors.neonGradient`/`ctaGradient`/`onCta`/`headlineGradient`,
  `lerpColorList`, `IconSizes`, `TapTargets`, `Spacing.gutter`,
  `Motion.press`/`stagger`/`staggerMaxItems`/`reducedCrossfade`/`reduced`,
  `AppFonts`, `PartyTextStyles.tabular`, `TimedTapTarget`, `AnswerTile`,
  `AnswerTileMode`, `AnswerMarker`, `AnswerShape`, `TimedCtaButton`,
  `PartyButton`, `PartyCard`, `PartyCardTone`, `GradientHeadline`,
  `PartyChip`, `StatusChip`, `PlayerAvatar`, `PlayerBadge`,
  `AnswerTimerRing`, `ResultPill`, `ResultKind`, `PointsGained`,
  `StreakChip`, `CelebrationBurst`, `PartyBanner`, `PartyBannerTone`,
  `showPartyToast`, `showPartySheet`, `PartyLoader`, `InlineSpinner`,
  `SkeletonRow`; ARB keys `gameMarkerCircle`/`Triangle`/`Square`/
  `Diamond`/`Hexagon`/`Star`, `gameAnswerSemantics`, `gameYourPick`,
  `gameTileCorrect`, `gameTimeLeftSemantics`, `revealStreak`,
  `playerBadgeHost`/`Dj`/`Ready` (Polish copy «[не проверено]» by a native
  speaker).
- **New names, fix round 1** «[новое имя — согласовать]»: `ReduceMotionScope`,
  `PartyActionBar`, `AnswerTile.splitLabel`, `AnswerTile.maxTextScale`,
  `TimedTapTarget.semanticsValue`, `YouTubePressPlayNote`,
  `RoundScreen.playerLayoutFor`, `RoundScreen.landscapePaneFloorWidth`,
  `RoundScreen.portraitControlsMinHeight`; ARB keys
  `gameYouTubePlayButton`, `gameYouTubeWindowTooSmall`, `commonLoading`
  (`gameYouTubePressPlay` now takes a `{playIcon}` placeholder). Earlier
  wave 6 names that were missing here: `StandingName`, `RoomCodeField`,
  `RoomCodeText`, `gameModeIcon`, `isPlayerRound`, `leaveRoom`; ARB keys
  `gameDjTapped`, `gameLeaveInlineConfirm`, `gameLeaveInlineCancel`,
  `lobbyCopyCode`, `lobbyCodeCopied`, `onboardingStepSemantics`,
  `standingsMovedUp`, `standingsMovedDown`, `resultsPodiumSemantics`.
  Removed: `PlayerAvatar.stableHash`, `GameController.youTubePlayerUnavailable`,
  the ARB key `gameYouTubeTapWhenPlaying` (the player screen says it once).

## Screen goldens (`test/goldens/`)

`screens_golden_test.dart` renders the real app (router, theme, bundled
fonts, fakes, no network) and compares the whole screen with
`test/goldens/screens/<name>.<light|dark>.png`: 32 frames per theme on a
390x844 phone at 3x (boot, home, onboarding, create-room sheet, join error,
settings, «Мои песни», lobby host/guest, countdown, whose_song DJ with the
player placeholder (portrait and 844x390 landscape), BYOP DJ, EEA consent,
round locked/open/answered/urgent/time-up, emoji puzzle, reveal right and
wrong, bonus offer, ad break, results, paywall; plus 360x640 and text
scale 2.0 frames). `flutter_test_config.dart` allows 0.2 % of pixels to
differ (Skia SIMD paths move a few anti-aliased pixels between CPUs).

- They are Linux renders and need the reference emoji font
  `/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf` from Ubuntu 24.04
  `fonts-noto-color-emoji` 2.047-0ubuntu0.24.04.1 (checked by length and
  hash). On any other OS, or without that exact file, the group is
  **skipped**, not failed: `flutter test` on a Mac or a CI image without the
  package does not check them.
- After an intended visual change: `flutter test test/goldens
  --update-goldens` on Linux, then look at every changed PNG.
  `GOLDEN_SHOTS_DIR=<dir>` also writes each frame at 3x for design review.

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
  resume with `hello.last_seq`), plus the DJ rotation, emoji quiz and
  account/consent suites. Wave 4: `youtube_embed_game_test.dart` (video and
  cue to the DJ only, consent before the player, `embed_disabled` →
  fallback video without a void, `dj_tap` start; consent declined → cue
  rounds and a rewarded bonus played as an emoji round) and
  `modes_enabled_test.dart` (guess_track refused at `/mode` by default).
- **Two servers.** `scripts/e2e.sh` starts a second server that also enables
  guess_track; `byop_guess_track_test.dart` runs against it through
  `E2E_GUESS_TRACK_API_BASE_URL` «[новое имя — согласовать]». The e2e config
  sets `ssv_optimistic_grant`, so the bonus is granted without a signed SSV
  callback (the signed path is covered by the server suites only). The suite
  drives `GameController` the way the YouTube player widget would; the real
  WebView is not exercised.

```sh
scripts/e2e.sh                                          # from the repo root
SKIP_BUILD=1 E2E_TESTS=test_e2e/byop_game_test.dart scripts/e2e.sh
```

## TODO(owner) before a store build

- YouTube (wave 4): run a youtube_embed round on a real iPhone and Android
  phone: the player loads with `https://<bundle id>` (no error 153), the
  raw error channel works, nothing overlays the player, audio stops on
  reveal and in the background. None of this has run on a device.
- Decide `youtube_player_min_width_dp` (480 does not fit portrait phones;
  356 is the YouTube floor) and the real `APP_BUNDLE_ID`.
- Android share intent into «Мои песни» (needs a plugin and an intent
  filter); today the link is pasted.
- Firebase: run `flutterfire configure` (adds GoogleService-Info.plist,
  google-services.json and the Google Services Gradle plugin); both files are
  git-ignored.
- AdMob: real app ids (`-PadmobAppId=` for Android, `GADApplicationIdentifier`
  in `ios/Runner/Info.plist`) and ad unit ids.
- RevenueCat public SDK keys; products per `docs/DEVELOPMENT.md` §8.
- Join links: `-PlinkHost=<domain>`, `assetlinks.json`, the iOS Associated
  Domains entitlement and `apple-app-site-association`.
- Brand name, bundle/application ids, store URLs, Terms and Privacy URLs.
- media3 version in `packages/sporand_native/android/build.gradle.kts`
  (not verifiable offline).
- Run the clock calibration screen on one iPhone and one Android phone
  (including after the device slept) and keep the reports.
- Settings has no «Выйти» / «Удалить аккаунт» entry yet: `AuthService.signOut`
  exists (it clears the analytics id), but `DELETE /v1/me` and its UI do not.
- Check the emoji line with the device emoji fonts (no custom font ships).

## CI

`.github/workflows/e2e.yml` runs `scripts/e2e.sh` (Node 22, pnpm, Flutter
3.47.5) when the server, the packages or the app change.

`.github/workflows/mobile.yml` runs on pushes and pull requests that touch
`apps/mobile/`: Flutter 3.47.5, `flutter pub get`, `flutter analyze
--no-fatal-infos` (errors and warnings fail; infos are reported) and
`flutter test --coverage` (the lcov report is uploaded as an artifact).
