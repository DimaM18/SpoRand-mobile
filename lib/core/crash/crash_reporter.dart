import 'dart:collection';

/// Crash/error reporting (Crashlytics on mobile, brief §3).
abstract interface class CrashReporter {
  Future<void> initialize({required bool collectionEnabled});

  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  });

  Future<void> log(String message);

  /// Pseudonymous id only (`analytics_uid`), never tokens or raw user data.
  Future<void> setUserId(String id);
}

final class RecordedError {
  const RecordedError(
    this.error,
    this.stack, {
    required this.fatal,
    this.reason,
  });

  final Object error;
  final StackTrace? stack;
  final bool fatal;
  final String? reason;
}

/// Buffers errors until the real reporter is initialized by the
/// `crash_reporting` boot step, then forwards everything to it.
///
/// `main()` installs the zone/Flutter/platform error handlers before any SDK
/// exists; they all report here so early boot crashes are not lost.
final class BufferingCrashReporter implements CrashReporter {
  BufferingCrashReporter({this.capacity = 50, this.onBufferedError});

  final int capacity;

  /// Debug hook (e.g. `debugPrint`) so buffered errors are still visible.
  final void Function(RecordedError error)? onBufferedError;

  CrashReporter? _delegate;
  final Queue<RecordedError> _pending = Queue<RecordedError>();
  final Queue<String> _pendingLogs = Queue<String>();
  String? _pendingUserId;

  bool get isAttached => _delegate != null;
  List<RecordedError> get pendingErrors => List.unmodifiable(_pending);

  /// Connects the initialized reporter and flushes the buffer in order.
  Future<void> attach(CrashReporter delegate) async {
    _delegate = delegate;
    final userId = _pendingUserId;
    if (userId != null) await delegate.setUserId(userId);
    while (_pendingLogs.isNotEmpty) {
      await delegate.log(_pendingLogs.removeFirst());
    }
    while (_pending.isNotEmpty) {
      final e = _pending.removeFirst();
      await delegate.recordError(
        e.error,
        e.stack,
        fatal: e.fatal,
        reason: e.reason,
      );
    }
  }

  @override
  Future<void> initialize({required bool collectionEnabled}) async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {
    final delegate = _delegate;
    if (delegate != null) {
      return delegate.recordError(error, stack, fatal: fatal, reason: reason);
    }
    final recorded = RecordedError(error, stack, fatal: fatal, reason: reason);
    onBufferedError?.call(recorded);
    _pending.addLast(recorded);
    while (_pending.length > capacity) {
      _pending.removeFirst();
    }
  }

  @override
  Future<void> log(String message) async {
    final delegate = _delegate;
    if (delegate != null) return delegate.log(message);
    _pendingLogs.addLast(message);
    while (_pendingLogs.length > capacity) {
      _pendingLogs.removeFirst();
    }
  }

  @override
  Future<void> setUserId(String id) async {
    final delegate = _delegate;
    if (delegate != null) return delegate.setUserId(id);
    _pendingUserId = id;
  }
}

/// In-memory reporter for tests and builds without Firebase.
final class FakeCrashReporter implements CrashReporter {
  FakeCrashReporter({this.failInitialize = false, this.onError});

  bool failInitialize;
  final void Function(RecordedError error)? onError;

  final List<RecordedError> errors = [];
  final List<String> logs = [];
  bool initialized = false;
  bool? collectionEnabled;
  String? userId;

  @override
  Future<void> initialize({required bool collectionEnabled}) async {
    if (failInitialize) throw StateError('crash reporting unavailable');
    initialized = true;
    this.collectionEnabled = collectionEnabled;
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {
    final recorded = RecordedError(error, stack, fatal: fatal, reason: reason);
    errors.add(recorded);
    onError?.call(recorded);
  }

  @override
  Future<void> log(String message) async => logs.add(message);

  @override
  Future<void> setUserId(String id) async => userId = id;
}
