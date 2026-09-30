import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/theme/app_theme.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/features/my_songs/data/my_songs_api.dart';
import 'package:sporand/features/my_songs/domain/picks_limits.dart';
import 'package:sporand/features/my_songs/presentation/my_songs_controller.dart';
import 'package:sporand/features/my_songs/presentation/my_songs_page.dart';

Future<FakeMySongsApi> _pumpPage(
  WidgetTester tester, {
  List<CatalogPick> picks = const [],
}) async {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  // Tall enough that the whole list is on screen (no scrolling needed).
  tester.view
    ..physicalSize = const Size(800, 3000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeMySongsApi(picks: picks);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [mySongsApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('ru'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MySongsPage(),
      ),
    ),
  );
  await tester.pump();
  return api;
}

Song _song(FakeMySongsApi api, String title) =>
    api.catalog.firstWhere((s) => s.title == title);

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byKey(const ValueKey('my-songs-search')), query);
  await tester.pump(MySongsController.debounce);
  await tester.pump();
}

Future<void> _add(WidgetTester tester, Song song) async {
  await tester.tap(find.byKey(ValueKey('add-${song.songId}')));
  await tester.pump();
}

FilledButton _saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const ValueKey('my-songs-save')));

void main() {
  testWidgets('search is debounced; pick 5 songs, save them in order with '
      'PUT /v1/me/picks; «Что увидят друзья» is shown', (tester) async {
    final api = await _pumpPage(tester);
    expect(find.text('Что увидят друзья'), findsOneWidget);
    expect(find.text('Выбрано 0 из 10'), findsOneWidget);

    // Typing fast sends one query, after the pause.
    final field = find.byKey(const ValueKey('my-songs-search'));
    await tester.enterText(field, 'Te');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'Tes');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'Test');
    await tester.pump(const Duration(milliseconds: 200));
    expect(api.queries, isEmpty);
    await tester.pump(MySongsController.debounce);
    await tester.pump();
    expect(api.queries, ['Test']);
    expect(find.text('Northern Lights'), findsOneWidget);
    expect(find.byType(Image), findsNothing, reason: 'no artwork');

    for (final title in ['Northern Lights', 'Slow River', 'Silver Lining']) {
      await _add(tester, _song(api, title));
    }
    expect(find.text('Выбрано 3 из 10'), findsOneWidget);
    expect(find.text('Добавьте ещё 2 песни'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);

    await _search(tester, 'Sample');
    for (final title in ['Paper Boats', 'Midnight Tram']) {
      await _add(tester, _song(api, title));
    }
    expect(find.text('Выбрано 5 из 10'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('my-songs-save')));
    await tester.pump();
    await tester.pump();
    expect(api.saved.single, [
      for (final title in [
        'Northern Lights',
        'Slow River',
        'Silver Lining',
        'Paper Boats',
        'Midnight Tram',
      ])
        _song(api, title).songId,
    ]);
    expect(find.text('Песни сохранены'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull, reason: 'nothing to save');
  });

  testWidgets('remove; a full selection disables adding', (tester) async {
    final catalog = FakeMySongsApi.sampleSongs;
    final api = await _pumpPage(
      tester,
      picks: [
        for (final (i, song) in catalog.take(10).indexed)
          SongPick(position: i + 1, song: song),
      ],
    );
    expect(find.text('Выбрано 10 из 10'), findsOneWidget);
    await _search(tester, 'Last Summer');
    final add = find.byKey(ValueKey('add-${_song(api, 'Last Summer').songId}'));
    expect(tester.widget<IconButton>(add).onPressed, isNull);

    final first = catalog.first.songId;
    await tester.tap(find.byKey(ValueKey('remove-$first')));
    await tester.pump();
    expect(find.text('Выбрано 9 из 10'), findsOneWidget);
    expect(find.byKey(ValueKey('pick-$first')), findsNothing);
    expect(tester.widget<IconButton>(add).onPressed, isNotNull);
    expect(_saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('a failed search says so', (tester) async {
    final api = await _pumpPage(tester);
    api.failWith = const ApiError(code: ApiError.network);
    await _search(tester, 'Neon');
    expect(find.text('Поиск не сработал. Проверьте интернет.'), findsOneWidget);
  });

  test('limits follow the room config within the protocol bounds', () {
    expect(PicksLimits.of(null).min, 5);
    expect(PicksLimits.of(null).max, 10);
    final strict = PicksLimits.of(
      const RoomConfig({
        'pool_min_tracks_per_contributor': 7,
        'pool_max_tracks_per_contributor': 50,
      }),
    );
    expect((strict.min, strict.max), (7, 10));
    final odd = PicksLimits.of(
      const RoomConfig({
        'pool_min_tracks_per_contributor': 3,
        'pool_max_tracks_per_contributor': 4,
      }),
    );
    expect((odd.min, odd.max), (5, 5));
  });
}
