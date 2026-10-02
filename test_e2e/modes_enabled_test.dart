// End-to-end: `modes_enabled` (wave 4) with its default value, whose_song and
// emoji_quiz. The audio mode guess_track stays in the code but is hidden: the
// server refuses it at POST /v1/rooms and in lobby.update_settings, and the
// app's mode picker offers only the enabled modes. See README.md,
// "End-to-end suite".
@Timeout(Duration(minutes: 2))
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';
import 'package:sporand/features/lobby/presentation/lobby_controller.dart';

import 'support/contract_audit.dart';
import 'support/e2e_env.dart';
import 'support/party.dart';

void main() {
  final audit = ContractAudit();
  setUpAll(requireRealNetwork);

  test('modes_enabled default: guess_track is refused at room creation and '
      'in lobby.update_settings, the lobby offers whose_song and emoji_quiz, '
      'and switching between those works', () async {
    final party = await Party.assemble(
      api: e2eApiBaseUrl()!,
      names: const ['Olek', 'Pola'],
      mode: GameMode.emojiQuiz,
      provider: MusicProviderId.none,
      audit: audit,
      pools: false,
    );
    addTearDown(party.dispose);
    addTearDown(() {
      for (final phone in party.phones) {
        printOnFailure(phone.wireSummary());
      }
    });
    final host = party.host;
    final guest = party.phones[1];

    // The room's frozen config carries the default.
    expect(
      host.session.config.modesEnabled,
      unorderedEquals([GameMode.whoseSong, GameMode.emojiQuiz]),
    );
    final view = (host.lobbyState as LobbyLoaded).view;
    expect(view.modeChoices, [GameMode.whoseSong, GameMode.emojiQuiz]);

    // POST /v1/rooms with guess_track: 400 validation_failed at /mode.
    final creator = await party.extraPhone('Rafał');
    final refused = await creator.tryCreateRoom(GameMode.guessTrack);
    expect(refused, isA<RoomOpenFailed>());
    final call = creator.rest.exchanges.lastWhere(
      (c) => c.method == 'POST' && c.path == '/v1/rooms',
    );
    expect(call.status, 400);
    final problem = Problem.fromJson(
      call.responseJson! as Map<String, Object?>,
    );
    expect(problem.code, 'validation_failed');
    expect(
      [for (final e in problem.errors ?? const <ProblemFieldError>[]) e.path],
      ['/mode'],
    );
    expect(creator.activeRoom, isA<NoActiveRoom>());

    // The picker never sends a hidden mode …
    final sentBefore = host.wire.sentOf('lobby.update_settings').length;
    host.lobby.setMode(GameMode.guessTrack);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(host.wire.sentOf('lobby.update_settings'), hasLength(sentBefore));

    // … and the server refuses one sent anyway (an old or modified client).
    final settings = host.session.room!.settings;
    final refusedAtUs = e2eNowUs();
    host.session.send(
      LobbyUpdateSettings(
        mode: GameMode.guessTrack,
        roundsTotal: settings.roundsTotal,
        explicitFilter: settings.explicitFilter,
        poolSources: const [PoolSource.catalogPicks],
      ),
    );
    final error = await host.waitMessage<ServerError>(
      'error',
      sinceUs: refusedAtUs,
      where: (f) => f.payload['ref_type'] == 'lobby.update_settings',
    );
    expect(error.code, ErrorCodes.validationFailed);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(host.session.room!.settings.mode, GameMode.emojiQuiz);
    expect(
      guest.wire
          .receivedOf('room.state')
          .where((f) => f.atUs >= refusedAtUs)
          .where((f) => f.payload['mode'] == 'guess_track'),
      isEmpty,
    );

    // An enabled mode goes through, for everyone.
    host.lobby.setMode(GameMode.whoseSong);
    for (final phone in party.phones) {
      await phone.waitFor(
        'room.state in whose_song',
        () => phone.session.room?.settings.mode == GameMode.whoseSong
            ? true
            : null,
      );
    }
    final after = (host.lobbyState as LobbyLoaded).view;
    expect(after.modeChoices, [GameMode.whoseSong, GameMode.emojiQuiz]);
    expect(guest.wire.receivedOf('error'), isEmpty);
  }, skip: e2eSkip());

  test(
    'contract: every frame and REST exchange decodes with the Dart DTOs',
    () {
      e2eLog('modes_enabled frames by type: ${audit.typeCounts}');
      expect(audit.problems(), isEmpty);
      expect(audit.clientProblems(), isEmpty);
      e2eLog('REST calls: ${audit.restCounts}');
      expect(audit.restProblems(), isEmpty);
      expect(audit.restCounts.keys, contains('POST /v1/rooms 400'));
    },
    skip: e2eSkip(),
  );
}
