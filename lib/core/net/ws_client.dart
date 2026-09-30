import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:clock/clock.dart' as clk;

import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/net/protocol/json_read.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_protocol.dart';
import 'package:sporand/core/net/ws_connection.dart';
import 'package:sporand/core/platform/app_platform.dart';

/// A single-use ticket from `POST /v1/rooms/{room_id}/ws-ticket` (valid
/// 30 s). Every connection attempt needs a fresh one.
final class WsTicket {
  const WsTicket({required this.ticket, this.wsUrl});

  final String ticket;

  /// Optional per-ticket endpoint (e.g. a specific instance); defaults to
  /// `wss://api.<domain>/v1/ws`.
  final Uri? wsUrl;
}

typedef WsTicketFetcher = Future<WsTicket> Function();

/// Why the client stopped for good (no automatic reconnect).
enum WsCloseReason {
  closedByClient,

  /// 4403: kicked by the host.
  kicked,

  /// 4409: another connection of this player replaced this one.
  replaced,

  /// 4426: the app must be updated.
  versionUnsupported,

  /// 4401 repeatedly, even with fresh tickets.
  unauthorized,

  /// The ticket endpoint says the room no longer exists.
  roomGone,
}

sealed class WsConnectionState {
  const WsConnectionState();
}

final class WsIdle extends WsConnectionState {
  const WsIdle();
}

final class WsConnecting extends WsConnectionState {
  const WsConnecting(this.attempt);

  final int attempt;
}

/// Socket open and `hello` sent; waiting for `welcome`.
final class WsHandshaking extends WsConnectionState {
  const WsHandshaking();
}

final class WsConnected extends WsConnectionState {
  const WsConnected();
}

final class WsReconnecting extends WsConnectionState {
  const WsReconnecting({
    required this.attempt,
    required this.delay,
    this.closeCode,
  });

  final int attempt;
  final Duration delay;
  final int? closeCode;
}

final class WsClosed extends WsConnectionState {
  const WsClosed(this.reason, {this.closeCode});

  final WsCloseReason reason;
  final int? closeCode;
}

/// Reconnect policy: exponential backoff with equal jitter.
final class WsBackoff {
  const WsBackoff({
    this.initial = const Duration(milliseconds: 500),
    this.max = const Duration(seconds: 15),
    this.rateLimitedMin = const Duration(seconds: 5),
    this.maxUnauthorizedRetries = 3,
  });

  final Duration initial;
  final Duration max;

  /// Floor after a 4429 close.
  final Duration rateLimitedMin;

  /// 4401 closes tolerated (each retry fetches a new ticket).
  final int maxUnauthorizedRetries;

  /// Half the capped exponential delay is fixed and half random, so clients
  /// that lost the same server do not reconnect in lockstep.
  Duration delayFor(int attempt, math.Random random) {
    final exp = initial.inMicroseconds * math.pow(2, math.min(attempt, 20));
    final capped = math.min(exp.toDouble(), max.inMicroseconds.toDouble());
    return Duration(
      microseconds: (capped / 2 + random.nextDouble() * capped / 2).round(),
    );
  }
}

/// The realtime client of one room (brief §4.3).
///
/// - Opens `wss://…/v1/ws` with a fresh ws-ticket and sends `hello` as the
///   first frame (the server closes with 4408 after 5 s otherwise).
/// - Client `seq` strictly increases per connection; the last server `seq`
///   is kept across connections and sent as `hello.last_seq` to resume.
/// - Answers `clock.ping` with `clock.pong` before any other processing,
///   stamping `t2_mono_us` with [InputClock.nowMicros].
/// - Reconnects with backoff and jitter; close codes 4403/4409/4426 (and
///   repeated 4401) are terminal.
/// - `server.draining` triggers a reconnect after `reconnect_after_ms`.
class WsClient {
  WsClient({
    required this._endpoint,
    required this._fetchTicket,
    required this._clock,
    required this._appVersion,
    required this._platform,
    this._connector = ChannelWsConnection.connect,
    this.backoff = const WsBackoff(),
    this.heartbeatTimeout = const Duration(seconds: 15),
    this.outboxTtl = const Duration(seconds: 30),
    this.outboxLimit = 32,
    math.Random? random,
    this._log,
  }) : _random = random ?? math.Random();

  final Uri _endpoint;
  final WsTicketFetcher _fetchTicket;
  final InputClock _clock;
  final String _appVersion;
  final AppPlatform _platform;
  final WsConnector _connector;
  final math.Random _random;
  final void Function(String message)? _log;

  final WsBackoff backoff;

  /// No frame for this long means the socket is dead (the server pings every
  /// `clock_sync_interval_ms`, 5 s by default); reconnect.
  final Duration heartbeatTimeout;
  final Duration outboxTtl;
  final int outboxLimit;

  static const _seqMemory = 512;

  final StreamController<ServerMessage> _messages =
      StreamController<ServerMessage>.broadcast();
  final StreamController<WsConnectionState> _states =
      StreamController<WsConnectionState>.broadcast();

  WsConnectionState _state = const WsIdle();
  WsConnection? _conn;
  StreamSubscription<Object?>? _sub;
  int _clientSeq = 0;
  int _lastServerSeq = 0;

  /// `hello.last_seq` of the current connection.
  int _resumeFromSeq = 0;
  final Set<int> _seenSeqs = <int>{};
  final Queue<int> _seenOrder = Queue<int>();
  int _attempt = 0;
  int _unauthorizedStrikes = 0;
  Timer? _reconnectTimer;
  Timer? _drainTimer;
  Timer? _watchdog;
  bool _stopped = false;
  bool _disposed = false;

  /// A connection attempt is fetching its ticket or opening the socket.
  bool _opening = false;
  final Stopwatch _uptime = clk.clock.stopwatch()..start();
  final Queue<({ClientMessage message, Duration queuedAt})> _outbox = Queue();

  Stream<ServerMessage> get messages => _messages.stream;

  Stream<WsConnectionState> get states => _states.stream;

  WsConnectionState get state => _state;

  bool get isConnected => _state is WsConnected;

  /// Highest server `seq` received (sent as `hello.last_seq`).
  int get lastServerSeq => _lastServerSeq;

  Future<void> connect() async {
    if (_stopped || _state is! WsIdle) return;
    await _open();
  }

  /// Sends [message] now when connected. Otherwise game messages are queued
  /// (bounded, [outboxTtl]) and sent right after the next `welcome`; hello,
  /// pongs and app-state updates are never queued. Returns false if dropped.
  bool send(ClientMessage message) {
    if (_stopped) return false;
    final conn = _conn;
    if (conn != null && _state is WsConnected) {
      _sendRaw(conn, message);
      return true;
    }
    if (message is Hello ||
        message is ClockPong ||
        message is AppStateMessage) {
      return false;
    }
    _outbox.addLast((message: message, queuedAt: _uptime.elapsed));
    while (_outbox.length > outboxLimit) {
      _outbox.removeFirst();
    }
    return true;
  }

  /// `app.state` on lifecycle and connectivity changes (brief §4.3). The
  /// server answers with a clock re-sync burst. Coming back to the
  /// foreground or onto a new network also cuts a pending backoff short.
  void notifyAppState(AppStateSignal signal) {
    if (_stopped) return;
    final conn = _conn;
    if (conn != null && _state is WsConnected) {
      _sendRaw(conn, AppStateMessage(signal));
    }
    if (signal != AppStateSignal.background && _state is WsReconnecting) {
      _attempt = 0;
      _reconnectTimer?.cancel();
      unawaited(_open());
    }
  }

  /// Leaves for good: closes the socket with 1000 and stops reconnecting.
  Future<void> close() async {
    if (_disposed) return;
    final conn = _conn;
    if (!_stopped) _stop(const WsClosed(WsCloseReason.closedByClient));
    _disposed = true;
    if (conn != null) {
      try {
        await conn.close(1000, 'bye');
      } on Object {
        // Already closed.
      }
    }
    await _messages.close();
    await _states.close();
  }

  // --- connection lifecycle -------------------------------------------------

  Future<void> _open() async {
    _reconnectTimer?.cancel();
    // One attempt at a time (a drain or foreground signal can arrive while
    // an attempt is still fetching its ticket).
    if (_stopped || _opening) return;
    _opening = true;
    try {
      await _openOnce();
    } finally {
      _opening = false;
    }
  }

  Future<void> _openOnce() async {
    _setState(WsConnecting(_attempt));
    final WsTicket ticket;
    try {
      ticket = await _fetchTicket();
    } on ApiError catch (e) {
      if (_stopped) return;
      _log?.call('ws-ticket failed: ${e.code}');
      switch (e.status) {
        case 403:
          _stop(const WsClosed(WsCloseReason.kicked));
        case 404:
          _stop(const WsClosed(WsCloseReason.roomGone));
        case 426:
          _stop(const WsClosed(WsCloseReason.versionUnsupported));
        default:
          _scheduleReconnect();
      }
      return;
    } on Object catch (e) {
      if (_stopped) return;
      _log?.call('ws-ticket failed: $e');
      _scheduleReconnect();
      return;
    }
    if (_stopped) return;

    final conn = _connector(ticket.wsUrl ?? _endpoint);
    _conn = conn;
    _clientSeq = 0;
    _sub = conn.frames.listen(
      _onFrame,
      onError: (Object error) => _log?.call('ws error: $error'),
      onDone: () => _onDone(conn),
    );
    try {
      await conn.ready.timeout(WsLimits.helloTimeout);
    } on Object catch (e) {
      _log?.call('ws connect failed: $e');
      if (identical(_conn, conn)) {
        unawaited(conn.close().catchError((Object _) {}));
        _onDone(conn);
      }
      return;
    }
    if (!identical(_conn, conn) || _stopped) return;
    _resumeFromSeq = _lastServerSeq;
    _sendRaw(
      conn,
      Hello(
        ticket: ticket.ticket,
        appVersion: _appVersion,
        platform: _platform,
        lastSeq: _lastServerSeq > 0 ? _lastServerSeq : null,
      ),
    );
    _setState(const WsHandshaking());
    _armWatchdog();
  }

  void _onDone(WsConnection conn) {
    if (!identical(conn, _conn)) return;
    _conn = null;
    unawaited(_sub?.cancel());
    _sub = null;
    _watchdog?.cancel();
    if (_stopped) return;
    final code = conn.closeCode;
    _log?.call('ws closed: $code ${conn.closeReason ?? ''}');
    switch (code) {
      case WsCloseCode.forbidden:
        _stop(WsClosed(WsCloseReason.kicked, closeCode: code));
      case WsCloseCode.replaced:
        // Reconnecting would fight the newer connection.
        _stop(WsClosed(WsCloseReason.replaced, closeCode: code));
      case WsCloseCode.versionUnsupported:
        _stop(WsClosed(WsCloseReason.versionUnsupported, closeCode: code));
      case WsCloseCode.unauthorized:
        _unauthorizedStrikes++;
        if (_unauthorizedStrikes > backoff.maxUnauthorizedRetries) {
          _stop(WsClosed(WsCloseReason.unauthorized, closeCode: code));
        } else {
          _scheduleReconnect(code: code);
        }
      case WsCloseCode.rateLimited:
        _scheduleReconnect(code: code, minDelay: backoff.rateLimitedMin);
      case WsCloseCode.serverDraining when _drainTimer?.isActive ?? false:
        // The drain timer from `server.draining` reconnects on schedule.
        _setState(
          WsReconnecting(
            attempt: _attempt,
            delay: Duration.zero,
            closeCode: code,
          ),
        );
      default:
        // 4408, 4500, 4503 without notice, 1006 and anything else.
        _scheduleReconnect(code: code);
    }
  }

  void _scheduleReconnect({int? code, Duration minDelay = Duration.zero}) {
    final jittered = backoff.delayFor(_attempt, _random);
    final delay = jittered < minDelay ? minDelay : jittered;
    _attempt++;
    _setState(WsReconnecting(attempt: _attempt, delay: delay, closeCode: code));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () => unawaited(_open()));
  }

  /// Drops the current socket (if any) and opens a new one immediately.
  void _reconnectNow() {
    if (_stopped) return;
    _reconnectTimer?.cancel();
    _watchdog?.cancel();
    final conn = _conn;
    _conn = null;
    unawaited(_sub?.cancel());
    _sub = null;
    if (conn != null) {
      unawaited(conn.close(1000, 'reconnect').catchError((Object _) {}));
    }
    unawaited(_open());
  }

  void _stop(WsClosed closed) {
    _stopped = true;
    _reconnectTimer?.cancel();
    _drainTimer?.cancel();
    _watchdog?.cancel();
    _outbox.clear();
    final conn = _conn;
    _conn = null;
    unawaited(_sub?.cancel());
    _sub = null;
    if (conn != null && closed.reason != WsCloseReason.closedByClient) {
      unawaited(conn.close().catchError((Object _) {}));
    }
    _setState(closed);
  }

  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(heartbeatTimeout, () {
      _log?.call('ws heartbeat lost');
      _reconnectNow();
    });
  }

  // --- frames ---------------------------------------------------------------

  void _onFrame(Object? data) {
    if (data is! String) return;
    // Stamp t2 before anything else: every microsecond spent before this
    // read biases the offset the server estimates (brief §5).
    final t2 = data.contains('"${WsServerMessage.clockPing}"')
        ? _readInputClock()
        : null;
    _armWatchdog();
    final WsEnvelope? envelope;
    try {
      envelope = WsEnvelope.tryParse(jsonDecode(data));
    } on FormatException {
      _log?.call('ws: dropped non-JSON frame');
      return;
    }
    if (envelope == null) return;
    if (envelope.type == WsServerMessage.welcome &&
        _resumeFromSeq > 0 &&
        envelope.seq <= _resumeFromSeq) {
      // Every frame the server sends after our hello has a seq above
      // `last_seq`, so a welcome at or below it means the server's stream
      // restarted (e.g. a deploy without the replay buffer). Count again.
      _seenSeqs.clear();
      _seenOrder.clear();
      _lastServerSeq = 0;
    }
    if (!_acceptSeq(envelope.seq)) return;

    if (envelope.type == WsServerMessage.clockPing && t2 != null) {
      _answerPing(envelope.payload, t2);
      return;
    }
    final ServerMessage message;
    try {
      message = ServerMessage.fromEnvelope(envelope);
    } on ProtocolFormatException catch (e) {
      _log?.call('ws: dropped ${envelope.type}: ${e.message}');
      return;
    }
    switch (message) {
      case Welcome():
        _attempt = 0;
        _unauthorizedStrikes = 0;
        _setState(const WsConnected());
        _flushOutbox();
      case ServerDraining(:final reconnectAfterMs):
        _drainTimer?.cancel();
        _drainTimer = Timer(Duration(milliseconds: reconnectAfterMs), () {
          _drainTimer = null;
          _reconnectNow();
        });
      default:
        break;
    }
    if (!_messages.isClosed) _messages.add(message);
  }

  /// Duplicates (replay overlap after `hello.last_seq`) are dropped; replayed
  /// frames the client has not seen are processed in arrival order.
  bool _acceptSeq(int seq) {
    if (_seenSeqs.contains(seq)) return false;
    _seenSeqs.add(seq);
    _seenOrder.addLast(seq);
    while (_seenOrder.length > _seqMemory) {
      _seenSeqs.remove(_seenOrder.removeFirst());
    }
    if (seq > _lastServerSeq) _lastServerSeq = seq;
    return true;
  }

  /// `t2_mono_us`, or null when the input clock could not be read: the
  /// server then just misses this sample. The native read starts
  /// synchronously, before the frame is decoded.
  Future<int?> _readInputClock() async {
    try {
      return await _clock.nowMicros();
    } on Object catch (e) {
      _log?.call('input clock read failed: $e');
      return null;
    }
  }

  void _answerPing(JsonMap payload, Future<int?> t2) {
    final ClockPing ping;
    try {
      ping = ClockPing.fromJson(payload);
    } on ProtocolFormatException {
      return;
    }
    final conn = _conn;
    unawaited(
      t2.then((t2MonoUs) {
        // A pong on a newer connection would pair with the wrong t1/t4.
        if (t2MonoUs == null ||
            conn == null ||
            !identical(conn, _conn) ||
            _stopped) {
          return;
        }
        _sendRaw(
          conn,
          ClockPong(
            pingId: ping.pingId,
            t1ServerUs: ping.t1ServerUs,
            t2MonoUs: t2MonoUs,
          ),
        );
      }),
    );
  }

  void _flushOutbox() {
    final conn = _conn;
    if (conn == null) return;
    final now = _uptime.elapsed;
    while (_outbox.isNotEmpty) {
      final queued = _outbox.removeFirst();
      if (now - queued.queuedAt > outboxTtl) continue;
      _sendRaw(conn, queued.message);
    }
  }

  void _sendRaw(WsConnection conn, ClientMessage message) {
    final frame = jsonEncode(message.toEnvelope(++_clientSeq).toJson());
    assert(
      utf8.encode(frame).length <= WsLimits.maxFrameBytes,
      'WS frames are limited to 8 KB (brief §4.3)',
    );
    try {
      conn.send(frame);
    } on Object catch (e) {
      _log?.call('ws send failed: $e');
    }
  }

  void _setState(WsConnectionState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
