import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_protocol.dart';
import 'package:sporand/core/net/ws_client.dart';
import 'package:sporand/core/platform/app_platform.dart';

import '../../support/fake_ws.dart';
import '../../support/protocol_samples.dart';

/// An input clock source whose platform channel is broken.
class _BrokenSource implements InputClockSource {
  int calls = 0;

  @override
  Future<int> nowOsUs() async {
    calls++;
    throw StateError('input clock unavailable');
  }
}

class _Harness {
  _Harness(this.async, {this.ticketError, InputClock? clock})
    : clock = clock ?? FakeInputClock(startUs: 5000000) {
    client = WsClient(
      endpoint: Uri.parse('wss://api.example.test/v1/ws'),
      fetchTicket: () async {
        final error = ticketError;
        if (error != null) throw error;
        tickets++;
        return WsTicket(ticket: 'wst_ticket_number_$tickets');
      },
      clock: this.clock,
      appVersion: '1.2.3',
      platform: AppPlatform.ios,
      connector: server.connect,
      random: math.Random(7),
    );
    client.states.listen(states.add);
    client.messages.listen(messages.add);
  }

  final FakeAsync async;
  Object? ticketError;
  final FakeWsServer server = FakeWsServer();
  final InputClock clock;
  late final WsClient client;
  final List<WsConnectionState> states = [];
  final List<ServerMessage> messages = [];
  int tickets = 0;

  void connect() {
    client.connect();
    async.flushMicrotasks();
  }

  void welcome() {
    server.send(Samples.welcome());
    async.flushMicrotasks();
  }

  void close(int? code) {
    server.current.serverClose(code);
    async.flushMicrotasks();
  }
}

void main() {
  test('sends hello first, with a fresh ticket and no last_seq', () {
    fakeAsync((async) {
      final h = _Harness(async)..connect();
      final first = h.server.current.sentEnvelopes.single;
      expect(first.type, WsClientMessage.hello);
      expect(first.seq, 1);
      expect(first.payload, {
        'ticket': 'wst_ticket_number_1',
        'app_version': '1.2.3',
        'platform': 'ios',
      });
      expect(h.client.state, isA<WsHandshaking>());
      h.welcome();
      expect(h.client.state, isA<WsConnected>());
      expect(h.messages.single, isA<Welcome>());
    });
  });

  test('client seq strictly increases on a connection', () {
    fakeAsync((async) {
      final h = _Harness(async)
        ..connect()
        ..welcome();
      h.client
        ..send(const LobbyReady(ready: true))
        ..send(const LobbyReady(ready: false))
        ..send(const GameStart());
      final seqs = [for (final e in h.server.current.sentEnvelopes) e.seq];
      expect(seqs, [1, 2, 3, 4]);
    });
  });

  test('answers clock.ping immediately with the anchored input clock as '
      't2', () {
    fakeAsync((async) {
      final h =
          _Harness(
              async,
              clock: FakeInputClock(startUs: 5000000, anchorUs: 4000000),
            )
            ..connect()
            ..welcome();
      final clock = h.clock as FakeInputClock..nowUs = 777000123;
      final callsBefore = clock.calls;
      h.server.send(
        const ClockPing(pingId: 'ping-9', t1ServerUs: 1759212345678901),
      );
      // A slow message right behind the ping must not delay the pong.
      h.server.send(
        const RoundProgress(roundId: 'r', answeredCount: 1, eligibleCount: 3),
      );
      async.flushMicrotasks();

      expect(clock.calls - callsBefore, 1);
      final sent = h.server.current.sentMessages;
      final pong = sent.whereType<ClockPong>().single;
      expect(pong.pingId, 'ping-9');
      expect(pong.t1ServerUs, 1759212345678901);
      expect(pong.t2MonoUs, 777000123 - 4000000, reason: 'OS time - anchor');
      // Pings are answered by the transport, not forwarded to the game.
      expect(h.messages.whereType<ClockPing>(), isEmpty);
      expect(h.messages.last, isA<RoundProgress>());
    });
  });

  test('a failing input clock skips the pong without an uncaught error', () {
    // Regression: the t2 read had no error handler, so a broken clock
    // channel raised an uncaught error on every ping.
    fakeAsync((async) {
      final source = _BrokenSource();
      final h = _Harness(async, clock: InputClock(source))
        ..connect()
        ..welcome();
      h.server.send(const ClockPing(pingId: 'ping-1', t1ServerUs: 1));
      h.server.send(
        const RoundProgress(roundId: 'r', answeredCount: 1, eligibleCount: 3),
      );
      async.flushMicrotasks();

      expect(source.calls, 1);
      expect(h.server.current.sent<ClockPong>(), isEmpty);
      expect(h.messages.last, isA<RoundProgress>());
      expect(h.client.isConnected, isTrue);
    });
  });

  test('stale duplicate frames (replay overlap) are dropped', () {
    fakeAsync((async) {
      final h = _Harness(async)
        ..connect()
        ..welcome();
      const progress = RoundProgress(
        roundId: 'r',
        answeredCount: 1,
        eligibleCount: 3,
      );
      h.server.current.deliver(progress, seq: 5);
      h.server.current.deliver(progress, seq: 5);
      h.server.current.deliver(
        const ClockPing(pingId: 'old', t1ServerUs: 1),
        seq: 5,
      );
      async.flushMicrotasks();
      expect(h.messages.whereType<RoundProgress>(), hasLength(1));
      expect(h.server.current.sent<ClockPong>(), isEmpty);
      expect(h.client.lastServerSeq, 5);
    });
  });

  test('reconnects with backoff, a new ticket and hello.last_seq', () {
    fakeAsync((async) {
      final h = _Harness(async)
        ..connect()
        ..welcome();
      h.server.send(RoomStateMessage(Samples.room()));
      async.flushMicrotasks();
      expect(h.client.lastServerSeq, 2);

      h.close(1006);
      final reconnecting = h.client.state as WsReconnecting;
      expect(reconnecting.closeCode, 1006);
      // Equal jitter: between half and all of the first 500 ms step.
      expect(reconnecting.delay.inMilliseconds, inInclusiveRange(250, 500));
      expect(h.server.connections, hasLength(1));

      async.elapse(reconnecting.delay);
      async.flushMicrotasks();
      expect(h.server.connections, hasLength(2));
      final hello = h.server.current.sentEnvelopes.single;
      expect(hello.seq, 1, reason: 'client seq restarts per connection');
      expect(hello.payload['ticket'], 'wst_ticket_number_2');
      expect(hello.payload['last_seq'], 2);

      // The server replays after last_seq; the seq stream continues.
      h.welcome();
      expect(h.client.state, isA<WsConnected>());
    });
  });

  test('backoff grows exponentially while failures continue', () {
    fakeAsync((async) {
      final h = _Harness(async)..connect();
      final delays = <Duration>[];
      for (var i = 0; i < 4; i++) {
        h.close(4500);
        final state = h.client.state as WsReconnecting;
        delays.add(state.delay);
        async.elapse(state.delay);
        async.flushMicrotasks();
      }
      expect(delays[1] > const Duration(milliseconds: 400), isTrue);
      expect(delays[3] >= const Duration(seconds: 2), isTrue);
      expect(delays[3] <= const Duration(seconds: 4), isTrue);
    });
  });

  group('close codes', () {
    for (final (code, reason) in [
      (WsCloseCode.forbidden, WsCloseReason.kicked),
      (WsCloseCode.replaced, WsCloseReason.replaced),
      (WsCloseCode.versionUnsupported, WsCloseReason.versionUnsupported),
    ]) {
      test('$code is terminal ($reason)', () {
        fakeAsync((async) {
          final h = _Harness(async)
            ..connect()
            ..welcome()
            ..close(code);
          final closed = h.client.state as WsClosed;
          expect(closed.reason, reason);
          expect(closed.closeCode, code);
          async.elapse(const Duration(minutes: 5));
          expect(h.server.connections, hasLength(1));
          expect(h.client.send(const GameStart()), isFalse);
        });
      });
    }

    test('4401 retries with a fresh ticket, then gives up', () {
      fakeAsync((async) {
        final h = _Harness(async)..connect();
        for (var attempt = 1; attempt <= 3; attempt++) {
          h.close(WsCloseCode.unauthorized);
          expect(h.client.state, isA<WsReconnecting>());
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
          expect(
            h.server.current.sentEnvelopes.first.payload['ticket'],
            'wst_ticket_number_${attempt + 1}',
          );
        }
        h.close(WsCloseCode.unauthorized);
        expect((h.client.state as WsClosed).reason, WsCloseReason.unauthorized);
      });
    });

    test('4408, 4500 and abnormal closes reconnect', () {
      fakeAsync((async) {
        final h = _Harness(async)..connect();
        for (final code in [
          WsCloseCode.helloTimeout,
          WsCloseCode.internalError,
          null,
        ]) {
          h.close(code);
          expect(h.client.state, isA<WsReconnecting>());
          // Shorter than the 15 s heartbeat, which would reconnect again.
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
        }
        expect(h.server.connections, hasLength(4));
      });
    });

    test('4429 waits at least the rate-limit floor', () {
      fakeAsync((async) {
        final h = _Harness(async)
          ..connect()
          ..close(WsCloseCode.rateLimited);
        final state = h.client.state as WsReconnecting;
        expect(state.delay >= const Duration(seconds: 5), isTrue);
        async.elapse(const Duration(seconds: 4));
        expect(h.server.connections, hasLength(1));
      });
    });

    test('a 403 on the ticket means kicked', () {
      fakeAsync((async) {
        final h = _Harness(
          async,
          ticketError: const ApiError(code: 'forbidden', status: 403),
        )..connect();
        expect((h.client.state as WsClosed).reason, WsCloseReason.kicked);
        expect(h.server.connections, isEmpty);
      });
    });
  });

  test('server.draining reconnects after reconnect_after_ms', () {
    fakeAsync((async) {
      final h = _Harness(async)
        ..connect()
        ..welcome();
      h.server.send(const ServerDraining(reconnectAfterMs: 2500));
      async.flushMicrotasks();
      // The server closes with 4503 first: wait for the announced time.
      h.close(WsCloseCode.serverDraining);
      async.elapse(const Duration(milliseconds: 2400));
      expect(h.server.connections, hasLength(1));
      async.elapse(const Duration(milliseconds: 200));
      async.flushMicrotasks();
      expect(h.server.connections, hasLength(2));
      expect(h.server.current.sentEnvelopes.single.payload['last_seq'], 2);
    });
  });

  test('server.draining alone also moves to a new connection', () {
    fakeAsync((async) {
      final h = _Harness(async)
        ..connect()
        ..welcome();
      h.server.send(const ServerDraining(reconnectAfterMs: 1000));
      async.elapse(const Duration(milliseconds: 1001));
      async.flushMicrotasks();
      expect(h.server.connections, hasLength(2));
      expect(h.server.connections.first.closedByClient, isTrue);
    });
  });

  test('messages sent while reconnecting are delivered after welcome', () {
    fakeAsync((async) {
      final h = _Harness(async)
        ..connect()
        ..welcome()
        ..close(1006);
      expect(h.client.send(const LobbyReady(ready: true)), isTrue);
      expect(
        h.client.send(const ClockPong(pingId: 'x', t1ServerUs: 1, t2MonoUs: 2)),
        isFalse,
        reason: 'pongs are never queued',
      );
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(h.server.current.sentMessages, hasLength(1)); // hello only
      h.welcome();
      final sent = h.server.current.sentMessages;
      expect(sent.last, isA<LobbyReady>());
      expect(h.server.current.sentEnvelopes.last.seq, 2);
    });
  });

  test('app.state is sent when connected; foreground cuts the backoff', () {
    fakeAsync((async) {
      final h = _Harness(async)
        ..connect()
        ..welcome();
      h.client.notifyAppState(AppStateSignal.background);
      expect(
        h.server.current.sent<AppStateMessage>().single.state,
        AppStateSignal.background,
      );
      h.close(1006);
      h.close(1006);
      h.client.notifyAppState(AppStateSignal.foreground);
      async.flushMicrotasks();
      expect(h.server.connections, hasLength(2));
    });
  });

  test('a silent socket is replaced after the heartbeat timeout', () {
    fakeAsync((async) {
      final h = _Harness(async)
        ..connect()
        ..welcome();
      async.elapse(const Duration(seconds: 14));
      expect(h.server.connections, hasLength(1));
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(h.server.connections, hasLength(2));
    });
  });

  test('a new welcome with an old seq resets the seq stream', () {
    fakeAsync((async) {
      final h = _Harness(async)
        ..connect()
        ..welcome();
      h.server.send(RoomStateMessage(Samples.room()));
      h.server.send(RoomStateMessage(Samples.room()));
      async.flushMicrotasks();
      h.close(1006);
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      // The server restarted without its replay buffer: seq starts over.
      h.server.seq = 0;
      h.welcome();
      h.server.send(RoomStateMessage(Samples.room()));
      async.flushMicrotasks();
      expect(h.messages.whereType<Welcome>(), hasLength(2));
      expect(h.messages.whereType<RoomStateMessage>(), hasLength(3));
      expect(h.client.lastServerSeq, 2);
    });
  });

  test('close() is final and closes with 1000', () {
    fakeAsync((async) {
      final h = _Harness(async)
        ..connect()
        ..welcome();
      h.client.close();
      async.flushMicrotasks();
      expect(h.server.current.clientCloseCode, 1000);
      async.elapse(const Duration(minutes: 1));
      expect(h.server.connections, hasLength(1));
    });
  });
}
