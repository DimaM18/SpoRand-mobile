import 'dart:convert';
import 'dart:io';

/// One song of the server's emoji catalogue, as far as the suite needs it.
typedef EmojiCatalogSong = ({
  String id,
  String title,
  String artist,
  int year,
  String market,
  String emoji,
});

/// The catalogue file the server loaded (see `e2eEmojiCatalogFile`): the
/// suite knows each puzzle's answer from it, since the server never says
/// which option is right before `round.reveal`.
List<EmojiCatalogSong> readEmojiCatalog(File file) {
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return [
    for (final song in json['songs']! as List<Object?>)
      if (song case final Map<String, Object?> s)
        (
          id: s['id']! as String,
          title: s['title']! as String,
          artist: s['artist']! as String,
          year: s['year']! as int,
          market: s['market']! as String,
          emoji: s['emoji']! as String,
        ),
  ];
}
