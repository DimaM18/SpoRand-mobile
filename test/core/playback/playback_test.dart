import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/playback/clip_player_adapter.dart';
import 'package:sporand/core/playback/playback_adapter.dart';
import 'package:sporand/core/playback/spotify_remote_playback_adapter.dart';
import 'package:sporand/features/game/domain/host_playback_coordinator.dart';
import 'package:sporand_native/sporand_native.dart';

import '../../support/protocol_samples.dart';

SpotifyPlayerState _state({
  bool paused = false,
  required int positionMs,
  int receiptUs = 50000000,
  String? uri = 'spotify:track:4uLU6hMCjMI75M1A2tKUQC',
}) => SpotifyPlayerState(
  isPaused: paused,
  playbackPositionMs: positionMs,
  receiptOsUs: receiptUs,
  trackUri: uri,
);

class _FakeBridge implements SpotifyRemoteBridge {
  final StreamController<SpotifyPlayerState> states =
      StreamController<SpotifyPlayerState>.broadcast();
  final List<String> calls = [];

  @override
  Future<void> connect() async => calls.add('connect');

  @override
  Future<void> play(String spotifyUri) async => calls.add('play $spotifyUri');

  @override
  Future<void> seekTo(int positionMs) async => calls.add('seek $positionMs');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Stream<SpotifyPlayerState> get playerStates => states.stream;

  @override
  Future<void> disconnect() async => calls.add('disconnect');
}

/// The generated Pigeon API, with the platform channel replaced.
class _FakeClipPlayerApi extends ClipPlayerApi {
  ClipSourceMessage? prepared;
  int? playAtUs;
  PlatformException? playError;

  @override
  Future<PreloadResultMessage> prepare(ClipSourceMessage clip) async {
    prepared = clip;
    return PreloadResultMessage(ok: true, preloadMs: 140);
  }

  @override
  Future<PlaybackStartedMessage> playAt(int startAtOsUs) async {
    final error = playError;
    if (error != null) throw error;
    playAtUs = startAtOsUs;
    return PlaybackStartedMessage(
      audioStartOsUs: startAtOsUs + 3000,
      outputLatencyMs: 180,
      outputRoute: OutputRouteMessage.bluetooth,
    );
  }
}

void main() {
  group('computeAudioStartFromPlayerState (brief §5, host-reported)', () {
    test('backdates the receipt by how far past the snippet start it is', () {
      expect(
        computeAudioStartFromPlayerState(
          state: _state(positionMs: 30120, receiptUs: 50000000),
          receiptMonoUs: 50000000,
          snippetStartMs: 30000,
        ),
        50000000 - 120000,
      );
    });

    test('a state slightly before the snippet start moves the start later', () {
      expect(
        computeAudioStartFromPlayerState(
          state: _state(positionMs: 29900, receiptUs: 50000000),
          receiptMonoUs: 50000000,
          snippetStartMs: 30000,
        ),
        50100000,
      );
    });

    test('accepts exactly snippet_start - 250 ms', () {
      expect(
        computeAudioStartFromPlayerState(
          state: _state(positionMs: 29750),
          receiptMonoUs: 50000000,
          snippetStartMs: 30000,
        ),
        isNotNull,
      );
    });

    test('rejects the pre-seek state (App Remote plays the track start)', () {
      expect(
        computeAudioStartFromPlayerState(
          state: _state(positionMs: 180),
          receiptMonoUs: 50000000,
          snippetStartMs: 30000,
        ),
        isNull,
      );
      expect(
        computeAudioStartFromPlayerState(
          state: _state(positionMs: 29749),
          receiptMonoUs: 50000000,
          snippetStartMs: 30000,
        ),
        isNull,
      );
    });

    test('rejects paused states and other tracks', () {
      expect(
        computeAudioStartFromPlayerState(
          state: _state(paused: true, positionMs: 30100),
          receiptMonoUs: 50000000,
          snippetStartMs: 30000,
        ),
        isNull,
      );
      expect(
        computeAudioStartFromPlayerState(
          state: _state(positionMs: 30100, uri: 'spotify:track:other'),
          receiptMonoUs: 50000000,
          snippetStartMs: 30000,
          expectedUri: 'spotify:track:4uLU6hMCjMI75M1A2tKUQC',
        ),
        isNull,
      );
    });
  });

  test('SpotifyRemotePlaybackAdapter: play, seek, first qualifying state; '
      'native receipt stamps go through the process anchor', () {
    fakeAsync((async) {
      final bridge = _FakeBridge();
      // OS time 10 s, anchor 4 s: mono time 6 s.
      final clock = FakeInputClock(
        startUs: 10000000,
        anchorUs: 4000000,
        clock: async.getClock(DateTime(2026)),
      );
      final adapter = SpotifyRemotePlaybackAdapter(
        bridge: bridge,
        clock: clock,
      );
      const clip = SpotifyRoundClip(
        spotifyUri: 'spotify:track:4uLU6hMCjMI75M1A2tKUQC',
        snippetStartMs: 30000,
        snippetDurationMs: 15000,
      );
      PreloadOutcome? preload;
      adapter.prepare(clip).then((value) => preload = value);
      async.flushMicrotasks();
      expect(preload?.ok, isTrue);

      PlaybackStarted? started;
      adapter.playAt(6500000).then((value) => started = value);
      async.elapse(const Duration(milliseconds: 499));
      expect(bridge.calls, ['connect']);
      async.elapse(const Duration(milliseconds: 2));
      expect(bridge.calls, [
        'connect',
        'play spotify:track:4uLU6hMCjMI75M1A2tKUQC',
        'seek 30000',
      ]);
      // Pre-seek state from the track start, then the real one.
      bridge.states.add(_state(positionMs: 200, receiptUs: 10520000));
      bridge.states.add(_state(positionMs: 30080, receiptUs: 10610000));
      async.flushMicrotasks();
      expect(started?.audioStartMonoUs, 10610000 - 4000000 - 80000);
      expect(started?.source, PlaybackStartSource.playerState);
      // The snippet ends snippet_duration_ms after the audio start.
      async.elapse(const Duration(seconds: 14));
      expect(bridge.calls.last, 'seek 30000');
      async.elapse(const Duration(seconds: 2));
      expect(bridge.calls.last, 'pause');
    });
  });

  test('SpotifyRemotePlaybackAdapter times out without a usable state', () {
    fakeAsync((async) {
      final bridge = _FakeBridge();
      final adapter = SpotifyRemotePlaybackAdapter(
        bridge: bridge,
        clock: FakeInputClock(clock: async.getClock(DateTime(2026))),
      );
      adapter.prepare(
        const SpotifyRoundClip(
          spotifyUri: 'spotify:track:x',
          snippetStartMs: 1000,
          snippetDurationMs: 5000,
        ),
      );
      async.flushMicrotasks();
      Object? error;
      adapter.playAt(0).catchError((Object e) {
        error = e;
        return const PlaybackStarted(
          audioStartMonoUs: 0,
          outputLatencyMs: 0,
          outputRoute: OutputRoute.other,
          source: PlaybackStartSource.playerState,
        );
      });
      async.elapse(const Duration(seconds: 6));
      expect((error! as PlaybackFailure).reason, PlaybackFailure.startTimeout);
    });
  });

  test(
    'the unavailable bridge fails prepare with spotify_not_running',
    () async {
      final adapter = SpotifyRemotePlaybackAdapter(
        bridge: const UnavailableSpotifyRemoteBridge(),
        clock: FakeInputClock(),
      );
      final outcome = await adapter.prepare(
        const SpotifyRoundClip(
          spotifyUri: 'spotify:track:x',
          snippetStartMs: 0,
          snippetDurationMs: 5000,
        ),
      );
      expect(outcome.ok, isFalse);
      expect(outcome.error, PlaybackFailure.spotifyNotRunning);
    },
  );

  group('ClipPlayerAdapter over the Pigeon API', () {
    test('maps the clip and the playback report; native times are raw OS '
        'time, the adapter converts through the process anchor', () async {
      final api = _FakeClipPlayerApi();
      final adapter = ClipPlayerAdapter(
        MusicProviderId.testCatalog,
        clock: FakeInputClock(anchorUs: 700000000),
        api: api,
      );
      final preload = await adapter.prepare(Samples.urlClip);
      expect(preload.ok, isTrue);
      expect(preload.preloadMs, 140);
      expect(api.prepared?.clipRef, Samples.urlClip.clipRef);
      expect(api.prepared?.snippetStartMs, 42000);
      final started = await adapter.playAt(834514845678);
      expect(api.playAtUs, 834514845678 + 700000000);
      expect(started.audioStartMonoUs, 834514845678 + 3000);
      expect(started.outputRoute, OutputRoute.bluetooth);
      expect(started.outputLatencyMs, 180);
      expect(started.source, PlaybackStartSource.scheduled);
    });

    test('native errors become playback failures', () async {
      final api = _FakeClipPlayerApi()
        ..playError = PlatformException(code: 'not_prepared');
      final adapter = ClipPlayerAdapter(
        MusicProviderId.testCatalog,
        clock: FakeInputClock(),
        api: api,
      );
      await expectLater(
        adapter.playAt(1),
        throwsA(
          isA<PlaybackFailure>().having(
            (f) => f.reason,
            'reason',
            'not_prepared',
          ),
        ),
      );
    });

    test('a Spotify clip cannot be prepared by the clip player', () async {
      final adapter = ClipPlayerAdapter(
        MusicProviderId.testCatalog,
        clock: FakeInputClock(),
        api: _FakeClipPlayerApi(),
      );
      final outcome = await adapter.prepare(
        const SpotifyRoundClip(
          spotifyUri: 'spotify:track:x',
          snippetStartMs: 0,
          snippetDurationMs: 5000,
        ),
      );
      expect(outcome.ok, isFalse);
    });
  });

  group('HostPlaybackCoordinator', () {
    test('reports preloaded + playback_started for the round', () async {
      final sent = <ClientMessage>[];
      final coordinator = HostPlaybackCoordinator(
        adapter: FakePlaybackAdapter(outputRoute: OutputRoute.airplay),
        send: (m) {
          sent.add(m);
          return true;
        },
      );
      final started = await coordinator.playRound(
        Samples.prepare(startAtMonoUs: 777, clip: Samples.urlClip),
      );
      expect(started?.outputRoute, OutputRoute.airplay);
      expect(sent.map((m) => m.type), [
        'round.preloaded',
        'round.playback_started',
      ]);
      expect((sent.last as RoundPlaybackStarted).audioStartMonoUs, 777);
    });

    test('prefetch reports each clip that names its round', () async {
      final adapter = FakePlaybackAdapter();
      final sent = <ClientMessage>[];
      final coordinator = HostPlaybackCoordinator(
        adapter: adapter,
        send: (m) {
          sent.add(m);
          return true;
        },
      );
      await coordinator.prefetch(
        const GameStarting(
          gameId: 'g',
          roundsTotal: 2,
          countdownMs: 3000,
          prefetch: [
            PrefetchClip(
              clipRef: 'clip_a',
              clipUrl: 'https://c/a',
              expiresAtServerMs: 1,
              roundId: 'r1',
            ),
            PrefetchClip(
              clipRef: 'clip_b',
              clipUrl: 'https://c/b',
              expiresAtServerMs: 1,
            ),
          ],
        ),
      );
      expect(adapter.prefetched, hasLength(2));
      expect(sent.whereType<RoundPreloaded>().single.roundId, 'r1');
    });

    test('a failed start is reported as round.playback_failed', () async {
      final sent = <ClientMessage>[];
      final coordinator = HostPlaybackCoordinator(
        adapter: FakePlaybackAdapter(playFailure: 'player_error'),
        send: (m) {
          sent.add(m);
          return true;
        },
      );
      final started = await coordinator.playRound(
        Samples.prepare(startAtMonoUs: 1, clip: Samples.urlClip),
      );
      expect(started, isNull);
      expect((sent.last as RoundPlaybackFailed).reason, 'player_error');
    });
  });
}
