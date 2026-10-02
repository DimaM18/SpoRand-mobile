# CLAUDE.md

Guidance for AI coding sessions in this repository. Read this first, then `README.md` and `docs/RUN.md`.

## Project

SpoRand (internal code name only; the public brand is not chosen and must not start with "Spo…") is a party music game for friends in one room, on iOS and Android. Players race to tap the answer on their phones:
- `whose_song` («Чья песня?», the main mode): the round DJ plays the song in the official embedded YouTube player (`youtube_embed`), with BYOP (`external_player`) as the fallback;
- `emoji_quiz` («Угадай песню» in the UI): 2–6 emoji encode a song title; no audio;
- `guess_track` (audio) stays in code but the server hides it (`modes_enabled`).

**Two repositories (since 2026-10-02).**
- **`DimaM18/SpoRand-mobile` (this one): the client.** The Flutter 3.47.5 app with Riverpod 3 (formerly `apps/mobile` of SpoRand; its history came along).
- **`DimaM18/SpoRand`: the backend.** Contracts (`packages/protocol`), game logic (`packages/game-core`), the authoritative server, the admin console, infra, and all documentation: the handbook `docs/DEVELOPMENT.md` (Russian) and `docs/DEPLOY.md`. References in code comments and READMEs to `docs/…`, `packages/…`, `apps/server` or `scripts/…` point there.

The app is a thin client: the server builds the randomized plan, validates answers and scores. The tap time is the OS pointer timestamp on the phone's input clock, never the network arrival time.

## The contract

- `contract/` is a copy of the backend's `packages/protocol/fixtures/` and `packages/protocol/generated/client-registry.json` at the commit `contract/SOURCE` pins. Never edit it by hand.
- `tool/contract.sh sync <SpoRand checkout>` copies it from a clean checkout and pins that commit; `tool/contract.sh check <SpoRand checkout>` fails on any difference. CI (`e2e.yml`) checks out the pinned commit, runs `check` and the end-to-end suite against that backend.
- A contract change lands in the backend first (its hard rule 8). Here it is a separate change: sync `contract/`, adapt the DTOs in `lib/core/net/protocol/`, make the drift tests pass (`test/core/net/contract_fixtures_test.dart`, `test/app/client_registry_test.dart`, `test/core/content_guard_test.dart`), keep the Dart analytics constants in step with the backend's event registry by hand (the drift tests do not compare events yet), and commit `contract/` together with the code.
- Wire policy: client → server payloads are strict, server → client payloads are open (unknown fields and unknown server message types are tolerated). Optional fields are omitted, never `null`. A new enum value needs a matching case here.
- If the handbook and the code disagree, the code with its tests decides; the handbook is updated in the backend repository. Do not diverge silently; say so in your report.

## Hard rules

1. **Never add Spotify API or SDK usage to public flavors.** Spotify Developer Policy III.2 bans games; `spotify_app_remote` is frozen. Spotify native code may only ever link into the `spotifyProto` flavor. No Spotify Web API calls, OAuth or scraping for taste data. Spotify data never goes to analytics, ads, Remote Config or crash reports.
2. **Never stream, bundle or play unlicensed audio.** Only `test_catalog` clips we hold a licence for and `licensed_clips` under contract. Tests and QA builds use synthetic sounds or `test_catalog` only. In BYOP the DJ's own music app plays the song (we get a `cue`); in `youtube_embed` YouTube's official player plays it (we get a `video` id and start offset). No cover art, no lyrics, no service logos.
3. **Content rules (owner decisions).** Russian, Belarusian, Ukrainian and other CIS songs and artists appear only in the opt-in emoji market `cis` («СНГ»; en «CIS», pl «WNP»), which only the host turns on; no locale default includes it (`EmojiMarket.localeDefaults`). The lobby hides its chip until the catalogue has `cis` songs (`lobbyEmojiMarkets`). No war- or hate-themed titles in test data either.
4. **No track, artist, title, playlist, video or taste data in analytics or ad calls** (Spotify URIs, YouTube video ids and URLs included). The app's guard is `sporandContentGuard` (`lib/core/analytics/analytics_service.dart`), the mirror of the backend's `SPORAND_CONTENT_GUARD`; a drift test compares it with `contract/generated/client-registry.json`. Events go only through `AnalyticsSink` with registry parameters. The only song reference allowed is the opaque `round_completed.emoji_id`. Ad requests carry no content targeting.
5. **Single entry point.** `lib/main.dart`: `main()` → `bootstrap()` (`runKitApp(sporandAppConfig)` of `mobile_kit`). All startup work runs as `InitStep`s in `AppInitializer` (stages `config` → `warmup` → `sdk_init` → `enter_app`); `buildBootSteps()` merges the kit's steps with the game's. No `main_<flavor>.dart`, no SDK initialization outside the pipeline. The flavor comes from `--dart-define=FLAVOR`.
6. **Tap timing comes from pointer events on the anchored input clock.** Answers (and the DJ's «Музыка играет!» tap) use `Listener.onPointerDown` with `PointerDownEvent.timeStamp` converted by `InputClock.fromOs`. Never `onTap` or `GestureDetector` for answers; never `DateTime.now()` or `Stopwatch` for game timing. Every `*_mono_us` on the wire is input-clock time minus the process anchor `anchor_us`; raw uptime never leaves the device (Apple required-reason 35F9.1). Only `InputClock` knows the anchor (`mobile_kit_clock`'s class, re-exported at `lib/core/clock/`, one instance: `inputClockProvider`). Native bridges carry raw `*_os_us` values.
7. **The server is authoritative.** The client never shuffles or scores. Correct answers arrive only with `round.reveal`. `clip` goes only to the playback device, `cue` and `video` only to the round's DJ. Entitlements come only from the server (RevenueCat re-fetch or AdMob SSV), never from client callbacks.
8. **Branch on `ProviderCapabilities`, never on provider ids,** in game logic and monetization.
9. **Change things additively.** `test_catalog`, `licensed_clips` and the frozen `spotify_app_remote` must keep working.
10. **YouTube (`youtube_embed`) follows the YouTube API Services policies** (full list: handbook §7 «YouTube: жёсткие правила»). Official IFrame player only, visible, at least 200×200 px, never audio-only, hidden or in the background. Nothing over the player; do not hide its title or channel; never block, skip or replace YouTube ads; never download, cache or proxy video or audio. The player identifies the app (origin `https://<bundle id>`); in the EEA/UK consent comes before the player is created, and a decline falls back to the BYOP `cue`. The DJ presses play; no autoplay. YouTube rounds are never paywalled or unlocked by ads. Our interstitial only on screens without the player. The round start is the DJ's «Музыка играет!» `dj_tap`, with the button outside the player; player state events are diagnostics only.

## Template packages

The base code (boot, services, screens, the input clock plugin) comes from the private template `mobile-template`, version **0.1.3**: `mobile_kit` and `mobile_kit_clock`, git dependencies in `pubspec.yaml` on `https://github.com/DimaM18/mobile-template.git` (`path: flutter/mobile_kit` / `flutter/mobile_kit_clock`, `ref: v0.1.3`; `pubspec.lock` pins the commit).
- `node tool/template-check.mjs` (a copy of the template's `scripts/template-check.mjs`) checks that each ref is a release tag `vX.Y.Z` and that no co-development overrides are committed; CI runs it. It does not compare the two refs with each other or with the backend's `@dimam18/*` version (there is no `package.json` here): keep both refs equal and in lockstep with the backend by hand on a bump. A template bump is a PR in each repository.
- The template's Flutter kits are moving to `https://github.com/DimaM18/mobile-template-flutter.git`, which has no tags until its first release (v0.1.4 or later). Until then keep the url above with `ref: v0.1.3`. On the first bump to it, change both urls, the `TEMPLATE_READ_TOKEN` scope and the `insteadOf` rule in `mobile.yml` and `e2e.yml` in one commit (mobile-template `docs/CONSUMING.md` §3.3 and §4). Co-development then uses `../mobile-template-flutter`.
- `flutter pub get` needs read access to the template repository: `gh auth setup-git` on a Mac, the `TEMPLATE_READ_TOKEN` secret in CI, the attached repository in a cloud session.
- Shims (old base files kept as re-exports and adapters) are the 8b compatibility layer and go away in wave 8c. New code imports `package:mobile_kit/…` or SpoRand's own `sporand*` code directly.
- A change to the base goes to the template first, then this repository bumps the refs (mind the url change above). Never edit `~/.pub-cache` or a copy of a kit file here. Co-development uses `pubspec_overrides.yaml` (git-ignored); never commit it.

## Commands

```sh
flutter pub get                                   # mobile_kit and mobile_kit_clock from the template repository (git, ref v0.1.3)
flutter analyze
flutter test                                      # incl. the drift tests against contract/
node tool/template-check.mjs
flutter gen-l10n                                  # after editing ARB files
dart run pigeon --input pigeons/<name>.dart       # after editing a Pigeon definition

tool/contract.sh sync ../SpoRand                  # take the backend contract (clean checkout at the commit to pin)
tool/contract.sh check ../SpoRand

E2E_MOBILE_DIR="$PWD" ../SpoRand/scripts/e2e.sh   # end-to-end: real servers from a backend checkout + test_e2e here
```

- The e2e suite (`test_e2e/`, 20 tests in 9 files) skips without `API_BASE_URL`, so plain `flutter test` never needs a server. The backend's `scripts/e2e.sh` builds the backend, starts two servers with short timings (the second also enables `guess_track`) and runs `flutter test test_e2e` here. It fails if the server sent a frame that violates the protocol.
- Test counts on 2026-10-02: 548 (incl. 64 screen goldens that need the Noto color emoji font; they skip in CI and on macOS); e2e 20.
- **This sandbox.** Flutter lives at `/opt/flutter-sdk/flutter/bin`. There is no Android SDK or Xcode, so only `flutter analyze`, `flutter test` and the e2e suite run.

## Conventions

- **Names.** Use the names already in the code and in the backend's protocol (enums, DTOs, registries) exactly. Any new name is marked «[новое имя — согласовать]» in `README.md` and listed in your report.
- **Language.** Code, comments and `README.md` are in English; `docs/RUN.md` is in Russian. UI copy is Russian first, through ARB files: `lib/core/l10n/arb/app_ru.arb` is the template, plus `app_en.arb` and `app_pl.arb`; every key needs all three; the output in `lib/core/l10n/gen/` is committed. Russian copy uses informal, gender-neutral «ты» (Polish: informal «ty»).
- **Evidence labels.** Keep «[проверено]», «[проверено косвенно]», «[не проверено]», «[наша оценка]» as they are.
- **Dependencies.** Pin exact versions. Do not add dependencies casually.
- **Tests and git.** Write the test first when fixing a bug. Strict types everywhere. Do not commit or push unless asked.

## Known unverified areas

- Native code compiled on the owner's Mac on 2026-09-30 (`flutter build ios --simulator --debug`, `flutter build apk --debug`) and the app ran on an iPhone simulator against a local server. It has not been rebuilt since wave 8b: the Swift and Kotlin of `mobile_kit_clock` and the reduced `sporand_native` have not compiled yet.
- `InputClockApi`, `ClipPlayerHost` and `MusicAppHost` have never run on a device; the clock calibration (`/debug/clock`, 2 iPhones and 3 Android phones) is pending.
- The embedded YouTube player has never run on a device (error 153 identity, raw error channel, pre-roll ads, dispose on reveal and background). `APP_BUNDLE_ID` is a placeholder.
- Firebase, RevenueCat and AdMob have no real projects or keys. Mobile kit behaviour in effect is unverified on devices (https-only `API_BASE_URL` outside dev, Google test ad units outside prod, RevenueCat catalogue product ids). Cleartext HTTP to a local server from device builds is unverified.
- This repository's CI (`mobile.yml`, `e2e.yml`) has not run yet; before the split the same workflows were green in `DimaM18/SpoRand`.
