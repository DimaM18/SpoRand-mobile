import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/platform/app_platform.dart';

/// Builders for protocol messages with realistic defaults.
abstract final class Samples {
  static const hostId = 'p-host';
  static const guestId = 'p-guest';
  static const thirdId = 'p-third';
  static const roomId = 'room-1';
  static const gameId = 'game-1';

  static PlayerSnapshot player(
    String id,
    String name, {
    PlayerRole role = PlayerRole.guest,
    bool playbackDevice = false,
    bool ready = true,
    bool contributor = true,
    int? poolTrackCount,
  }) => PlayerSnapshot(
    playerId: id,
    displayName: name,
    role: role,
    isContributor: contributor,
    isPlaybackDevice: playbackDevice,
    connection: PlayerConnection.connected,
    platform: AppPlatform.android,
    ready: ready,
    poolTrackCount: poolTrackCount ?? (contributor ? 5 : 0),
  );

  static List<PlayerSnapshot> players() => [
    player(hostId, 'Ania', role: PlayerRole.host, playbackDevice: true),
    player(guestId, 'Bartek'),
    player(thirdId, 'Celina'),
  ];

  /// `provider_capabilities` of an external_player (BYOP) room, as in
  /// packages/protocol `fixtures/ws/variants/s2c/room.state/byop.json`.
  static const byopCapabilities = ProviderCapabilities(
    playback: AudioStartSource.hostReported,
    audioSource: AudioSource.externalApp,
    allowsMonetization: true,
    allowsPrefetch: false,
    allowsCustomOffset: false,
    revealsMetadataDuringPlay: true,
    licensedTerritories: ['*'],
    requiresPremiumHost: false,
    supportsSearch: true,
  );

  static const textCapabilities = ProviderCapabilities(
    playback: AudioStartSource.none,
    audioSource: AudioSource.none,
    allowsMonetization: true,
    allowsPrefetch: false,
    allowsCustomOffset: false,
    revealsMetadataDuringPlay: false,
    licensedTerritories: ['*'],
    requiresPremiumHost: false,
    supportsSearch: true,
  );

  static RoomSnapshot room({
    RoomState state = RoomState.lobby,
    GameMode mode = GameMode.guessTrack,
    HostTier tier = HostTier.free,
    List<PlayerSnapshot>? players,
    MusicProviderId provider = MusicProviderId.testCatalog,
    ProviderCapabilities? capabilities,
  }) => RoomSnapshot(
    roomId: roomId,
    roomCode: '7KQ2MX',
    state: state,
    hostPlayerId: hostId,
    players: players ?? Samples.players(),
    settings: RoomSettings(
      mode: mode,
      roundsTotal: 10,
      maxPlayers: 8,
      shuffleStrategy: ShuffleStrategy.spreadConstrained,
      explicitFilter: false,
      poolSources: const [PoolSource.catalogPicks],
    ),
    mode: mode,
    provider: provider,
    providerCapabilities: capabilities,
    audioMode: AudioMode.hostDevice,
    hostTier: tier,
  );

  /// An external_player room (the host is the DJ).
  static RoomSnapshot byopRoom({
    RoomState state = RoomState.roundPlaying,
    GameMode mode = GameMode.whoseSong,
  }) => room(
    state: state,
    mode: mode,
    provider: MusicProviderId.externalPlayer,
    capabilities: byopCapabilities,
  );

  static Welcome welcome({
    String me = guestId,
    RoomSnapshot? room,
    Map<String, Object?> config = const {
      'rounds_free_options': [5, 10],
      'rounds_premium_options': [5, 10, 15, 25, 50],
      'answer_window_ms': 15000,
    },
  }) => Welcome(
    playerId: me,
    room: room ?? Samples.room(),
    config: RoomConfig(config),
    configVersion: '18a4b88131908136',
    serverVersion: '0.1.0',
  );

  static const options = [
    RoundOption(optionId: 'opt-a', label: 'Ania', avatar: 'fox'),
    RoundOption(optionId: 'opt-b', label: 'Bartek'),
    RoundOption(optionId: 'opt-c', label: 'Celina'),
  ];

  static RoundPrepare prepare({
    String roundId = 'round-1',
    int roundIndex = 0,
    required int startAtMonoUs,
    bool youAreOwner = false,
    AudioStartSource source = AudioStartSource.scheduled,
    RoundKind kind = RoundKind.regular,
    RoundClip? clip,
    RoundCue? cue,
    RoundTextPrompt? textPrompt,
    RoundPrompt prompt = RoundPrompt.whoseSong,
    int startAtServerMs = 1759212348178,
    int answerWindowMs = 15000,
  }) => RoundPrepare(
    roundId: roundId,
    roundIndex: roundIndex,
    kind: kind,
    nonce: '4f1d9c2b7a6e5d3c2b1a0f9e8d7c6b5a',
    prompt: prompt,
    options: options,
    youAreOwner: youAreOwner,
    startAtServerMs: startAtServerMs,
    startAtMonoUs: startAtMonoUs,
    answerWindowMs: answerWindowMs,
    audioStartSource: source,
    commitHash:
        'fcb326c4a60b146025d44fa3758ccf983a9ce51c58ad53ae325186ab48767c35',
    clip: clip,
    cue: cue,
    textPrompt: textPrompt,
  );

  static const cue = RoundCue(
    title: 'Northern Lights',
    artists: ['Test Artist', 'Example Choir'],
    hintUrl: 'https://music.example.invalid/search?q=Northern%20Lights',
  );

  /// The DJ's round.prepare in an external_player room.
  static RoundPrepare djPrepare({
    String roundId = 'round-1',
    required int startAtMonoUs,
    RoundPrompt prompt = RoundPrompt.whoseSong,
    bool youAreOwner = false,
  }) => prepare(
    roundId: roundId,
    startAtMonoUs: startAtMonoUs,
    source: AudioStartSource.hostReported,
    prompt: prompt,
    youAreOwner: youAreOwner,
    cue: cue,
  );

  /// A whose_song text round (provider none).
  static RoundPrepare textPrepare({
    String roundId = 'round-1',
    required int startAtMonoUs,
  }) => prepare(
    roundId: roundId,
    startAtMonoUs: startAtMonoUs,
    source: AudioStartSource.none,
    prompt: RoundPrompt.textRound,
    textPrompt: const RoundTextPrompt(
      title: 'Paper Boats',
      artists: ['Sample Band'],
    ),
  );

  static const urlClip = UrlRoundClip(
    clipUrl: 'https://clips.example.invalid/c/abc.m4a?sig=x',
    clipRef: 'clip_0a1b2c3d4e5f6a7b',
    snippetStartMs: 42000,
    snippetDurationMs: 15000,
  );

  static RoundReveal reveal({
    String roundId = 'round-1',
    List<String> correct = const ['opt-c'],
    List<RoundResult>? results,
    List<Standing>? standings,
  }) => RoundReveal(
    roundId: roundId,
    correctOptionIds: correct,
    commitSalt: 'b3c1f0e9d8a7b6c5d4e3f2a1b0c9d8e7',
    track: const RevealTrack(
      title: 'Northern Lights',
      artists: ['Test Artist'],
      attribution: TrackAttribution(
        provider: MusicProviderId.testCatalog,
        text: 'Music: Test Artist (licensed)',
      ),
    ),
    ownerPlayerIds: const [thirdId],
    results:
        results ??
        const [
          RoundResult(
            playerId: guestId,
            optionId: 'opt-c',
            correct: true,
            reactionMs: 842,
            points: 986,
            streak: 1,
            validation: AnswerValidation.ok,
          ),
          RoundResult(playerId: hostId, correct: false, points: 0, streak: 0),
        ],
    standings:
        standings ??
        const [
          Standing(
            playerId: guestId,
            rank: 1,
            points: 986,
            correctCount: 1,
            correctReactionMsSum: 842,
          ),
          Standing(
            playerId: hostId,
            rank: 2,
            points: 0,
            correctCount: 0,
            correctReactionMsSum: 0,
          ),
          Standing(
            playerId: thirdId,
            rank: 2,
            points: 0,
            correctCount: 0,
            correctReactionMsSum: 0,
          ),
        ],
  );

  static GameResults results() => GameResults(
    gameId: gameId,
    standings: reveal().standings,
    roundsPlayed: 10,
    bonusUsed: false,
  );

  /// One sample of every server message type.
  static List<ServerMessage> allServerMessages() => [
    welcome(),
    const ClockPing(pingId: 'ping-1', t1ServerUs: 1759212345678901),
    const ClockResult(
      offsetUs: -1234567,
      rttMinUs: 23000,
      samples: 8,
      quality: ClockQuality.good,
    ),
    RoomStateMessage(room(state: RoomState.results)),
    RoomPlayerJoined(player('p-new', 'Dima')),
    const RoomPlayerLeft(playerId: 'p-new', reason: PlayerLeftReason.kicked),
    RoomPlayerUpdated(player(guestId, 'Bartek', ready: false)),
    const RoomClosed(RoomClosedReason.hostLeft),
    const GameStarting(
      gameId: gameId,
      roundsTotal: 10,
      countdownMs: 3000,
      prefetch: [
        PrefetchClip(
          clipRef: 'clip_0a1b2c3d4e5f6a7b',
          clipUrl: 'https://clips.example.invalid/c/abc.m4a?sig=x',
          expiresAtServerMs: 1759213245000,
          roundId: 'round-1',
        ),
      ],
    ),
    prepare(startAtMonoUs: 834514845678, clip: urlClip),
    prepare(
      roundId: 'round-2',
      startAtMonoUs: 834514845678,
      source: AudioStartSource.hostReported,
      clip: const SpotifyRoundClip(
        spotifyUri: 'spotify:track:4uLU6hMCjMI75M1A2tKUQC',
        snippetStartMs: 30000,
        snippetDurationMs: 15000,
      ),
    ),
    djPrepare(roundId: 'round-3', startAtMonoUs: 834514845678),
    textPrepare(roundId: 'round-4', startAtMonoUs: 834514845678),
    RoomStateMessage(byopRoom()),
    const RoundStart(roundId: 'round-1', audioStartServerMs: 1759212348201),
    const RoundAnswerAck(roundId: 'round-1', accepted: true),
    const RoundAnswerAck(
      roundId: 'round-1',
      accepted: false,
      reason: AnswerValidation.tooEarly,
    ),
    const RoundAnswerAck(
      roundId: 'round-1',
      accepted: false,
      reason: AnswerValidation.djIneligible,
    ),
    const RoundProgress(roundId: 'round-1', answeredCount: 2, eligibleCount: 3),
    const RoundVoided(
      roundId: 'round-1',
      reason: RoundVoidReason.playbackTimeout,
    ),
    reveal(),
    const GameBonusOffer(
      bonusId: 'bonus-1',
      expiresAtServerMs: 1759212360000,
      eligiblePlayerIds: [guestId, thirdId],
    ),
    const BonusSponsorLocked(
      bonusId: 'bonus-1',
      sponsorPlayerId: guestId,
      expiresAtServerMs: 1759212420000,
    ),
    const BonusNonce(
      bonusId: 'bonus-1',
      rewardNonce: 'nonce_1a2b3c4d5e6f7a8b9c0d',
      ssvUserId: 'ssv_9f8e7d6c5b4a3f2e1d0c',
    ),
    const BonusGranted(
      bonusId: 'bonus-1',
      sponsorPlayerId: guestId,
      roundsAdded: 1,
    ),
    const BonusCancelled(
      bonusId: 'bonus-1',
      reason: BonusCancelReason.ssvTimeout,
    ),
    const GameAdBreak(
      gameId: gameId,
      resultsRevealAtServerMs: 1759212500000,
      showInterstitial: true,
      showRemoveAdsUpsell: true,
    ),
    results(),
    const PlayerEntitlementsUpdated(
      playerId: guestId,
      noAds: true,
      premium: false,
    ),
    const ServerDraining(reconnectAfterMs: 2500),
    const ServerError(
      code: ErrorCodes.poolInsufficient,
      message: 'contributor pools too small',
      refType: 'game.start',
    ),
  ];

  /// One sample of every client message type.
  static List<ClientMessage> allClientMessages() => const [
    Hello(
      ticket: 'wst_4f9d2c7a1b8e6f3d0c5a9b2e',
      appVersion: '1.0.0',
      platform: AppPlatform.ios,
      lastSeq: 41,
    ),
    Hello(
      ticket: 'wst_4f9d2c7a1b8e6f3d0c5a9b2e',
      appVersion: '1.0.0',
      platform: AppPlatform.android,
    ),
    ClockPong(
      pingId: 'ping-1',
      t1ServerUs: 1759212345678901,
      t2MonoUs: 834512345678,
    ),
    AppStateMessage(AppStateSignal.networkChanged),
    LobbyReady(ready: true),
    LobbyUpdateSettings(
      mode: GameMode.whoseSong,
      roundsTotal: 10,
      shuffleStrategy: ShuffleStrategy.spreadConstrained,
      explicitFilter: false,
      poolSources: [PoolSource.catalogPicks],
    ),
    LobbyKick(playerId: 'p-guest'),
    GameStart(),
    RoundPreloaded(roundId: 'round-1', ok: true, preloadMs: 412),
    RoundPlaybackStarted(
      roundId: 'round-1',
      audioStartMonoUs: 834514845678,
      outputLatencyMs: 23,
      outputRoute: OutputRoute.speaker,
      source: PlaybackStartSource.scheduled,
    ),
    RoundPlaybackStarted(
      roundId: 'round-3',
      audioStartMonoUs: 2056435,
      outputLatencyMs: 0,
      outputRoute: OutputRoute.other,
      source: PlaybackStartSource.djTap,
    ),
    RoundPlaybackFailed(roundId: 'round-1', reason: 'clip_load_failed'),
    RoundAnswer(
      roundId: 'round-1',
      nonce: '4f1d9c2b7a6e5d3c2b1a0f9e8d7c6b5a',
      optionId: 'opt-c',
      tapMonoUs: 834515687654,
      unlockMonoUs: 834514853012,
    ),
    BonusRequest(bonusId: 'bonus-1', appCheckToken: 'limited-use-token-123'),
    BonusRequest(bonusId: 'bonus-1'),
    BonusAdResult(bonusId: 'bonus-1', status: BonusAdStatus.earned),
    AdInterstitialResult(
      gameId: gameId,
      result: InterstitialWireResult.shown,
      waitMs: 312,
    ),
    GamePlayAgain(),
    RoomLeave(),
  ];
}
