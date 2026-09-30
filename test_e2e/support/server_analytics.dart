import 'dart:convert';
import 'dart:io';

/// One server analytics event as `ConsoleAnalyticsSink` logs it.
typedef ServerEvent = ({
  String name,
  Map<String, Object?> params,
  String? analyticsUid,
});

/// Reads the server analytics events from the server log (see
/// `e2eServerLog`): the lines `{"analytics": {...}}` that
/// `ConsoleAnalyticsSink` writes after validation and the consent gate.
List<ServerEvent> readServerEvents(File log) {
  final events = <ServerEvent>[];
  for (final line in log.readAsLinesSync()) {
    if (!line.startsWith('{"analytics":')) continue;
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      continue;
    }
    if (decoded is! Map<String, Object?>) continue;
    final event = decoded['analytics'];
    if (event is! Map<String, Object?>) continue;
    events.add((
      name: event['name']! as String,
      params: (event['params'] as Map<String, Object?>?) ?? const {},
      analyticsUid: event['analytics_uid'] as String?,
    ));
  }
  return events;
}

/// The raw analytics lines of the log, for content checks.
List<String> serverAnalyticsLines(File log) => [
  for (final line in log.readAsLinesSync())
    if (line.startsWith('{"analytics":')) line,
];
