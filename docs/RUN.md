# SpoRand-mobile — запуск и проверки

Приложение SpoRand (iOS и Android) на Flutter 3.47.5 и Riverpod 3. Бэкенд, контракты и справочник проекта (`docs/DEVELOPMENT.md`) живут в репозитории `DimaM18/SpoRand`; здесь только клиент. Правила для AI-сессий — [`CLAUDE.md`](../CLAUDE.md), подробности по коду — [`README.md`](../README.md) (на английском).

## Что нужно

- Flutter 3.47.5 (stable); Xcode и Android SDK для нативных сборок.
- Доступ на чтение к репозиторию шаблона `DimaM18/mobile-template-flutter`: `flutter pub get` клонирует `mobile_kit` и `mobile_kit_clock` git'ом (на Mac хватит `gh auth setup-git`).
- Для игры против локального сервера и для сквозного прогона — клон `DimaM18/SpoRand` рядом (`../SpoRand`) с Node 22+, pnpm и токеном пакетов шаблона (`README.md` там, «Пакеты шаблона»).

## Запуск

Точка входа одна: `lib/main.dart` (`main()` → `bootstrap()`). Флейвор и окружение задаются через `--dart-define`:

```sh
flutter pub get
flutter run                                                   # dev: офлайн-фейки, без Firebase
flutter run --dart-define=FLAVOR=dev --dart-define=API_BASE_URL=http://localhost:8080
flutter run --dart-define=FLAVOR=staging --dart-define=API_BASE_URL=https://api.<domain>
```

- `FLAVOR`: `dev` (по умолчанию), `staging`, `prod` или `spotifyProto` (заморожен).
- `API_BASE_URL`: адрес REST; WebSocket открывается на том же хосте. Если его не задать, комнаты не открываются. Только `https`; `http` разрешён лишь во флейворе `dev` к локальному или частному адресу (`localhost`, `10.0.2.2`, `192.168.x.x`).
- `ROOM_PROVIDER`: какой провайдер просить для новой комнаты. По умолчанию `test_catalog` в `dev` и `external_player` в `staging` и `prod`.
- Остальные параметры (Firebase, RevenueCat, AdMob, ссылки) описаны в [`README.md`](../README.md).
- В Android-эмуляторе локальный сервер доступен как `http://10.0.2.2:8080`. Пропустит ли сборка на устройстве обычный HTTP, не проверено: при ошибке используй HTTPS-туннель.

## Запуск из Xcode / Android Studio / VS Code

- **VS Code.** В `.vscode/launch.json` три конфигурации: «dev: local server + iOS simulator» (`API_BASE_URL=http://localhost:8080`, `ROOM_PROVIDER=external_player`), «dev: local server + Android emulator» (`http://10.0.2.2:8080`) и «dev: offline fakes». Нужно расширение Flutter; сервер запусти отдельно, в клоне `DimaM18/SpoRand`: `pnpm --filter @sporand/server dev`.
- **Android Studio.** Открой корень этого репозитория. Run → Edit Configurations → Flutter: entrypoint `lib/main.dart`, в «Additional run args» — те же `--dart-define`, например `--dart-define=FLAVOR=dev --dart-define=API_BASE_URL=http://10.0.2.2:8080 --dart-define=ROOM_PROVIDER=external_player`.
- **Xcode.** Открой `ios/Runner.xcworkspace` (не `.xcodeproj`).
  - Xcode не принимает `--dart-define`: он читает значения из `ios/Flutter/Generated.xcconfig`, который записывает последний `flutter run` или `flutter build ios`. Сначала выполни `flutter build ios --simulator --debug --dart-define=FLAVOR=dev --dart-define=API_BASE_URL=http://localhost:8080 --dart-define=ROOM_PROVIDER=external_player`, потом Run в Xcode. Смена define — снова `flutter build`.
  - Hot reload из Xcode нет. Для hot reload и логов Dart подключись к запущенному приложению: `flutter attach`.
  - Xcode нужен для отладки Swift в `packages/sporand_native` и для подписи.

## Проверки

```sh
flutter pub get
flutter analyze
flutter test                         # в том числе тесты дрейфа против contract/
node tool/template-check.mjs         # каждая ссылка на шаблон — тег vX.Y.Z, нет локальных подмен (обе ссылки равны; совпадение с версией бэкенда смотри руками)
flutter gen-l10n                     # после правки ARB (ru — шаблон, плюс en и pl)
dart run pigeon --input pigeons/<name>.dart   # после правки определения Pigeon
```

## Контракт бэкенда

`contract/` — копия `packages/protocol/fixtures/` и `packages/protocol/generated/client-registry.json` из `DimaM18/SpoRand` на коммите из `contract/SOURCE`. Руками её не правят.

```sh
git -C ../SpoRand pull                     # нужный коммит бэкенда, без локальных правок в packages/protocol
tool/contract.sh sync ../SpoRand           # скопировать контракт и закрепить коммит
flutter test                               # тесты дрейфа покажут, что адаптировать в lib/core/net/protocol/
tool/contract.sh check ../SpoRand          # копия совпадает с клоном (CI делает то же на закреплённом коммите)
```

Изменение контракта начинается в бэкенде (его `CLAUDE.md`, правило 8); здесь — отдельный PR: `contract/` вместе с изменёнными DTO.

## Сквозной прогон

Настоящий сервер плюс набор `test_e2e/` по настоящим сокетам. Скрипт живёт в бэкенде:

```sh
E2E_MOBILE_DIR="$PWD" ../SpoRand/scripts/e2e.sh                  # сборка бэкенда, два сервера, flutter test test_e2e здесь
SKIP_BUILD=1 E2E_MOBILE_DIR="$PWD" ../SpoRand/scripts/e2e.sh     # бэкенд уже собран
```

Если клон приложения лежит рядом с бэкендом как `SpoRand-mobile`, `E2E_MOBILE_DIR` можно не задавать. В CI (`.github/workflows/e2e.yml`) бэкенд берётся ровно на коммите из `contract/SOURCE`.

## CI и секреты

- `mobile.yml`: `tool/template-check.mjs`, `flutter analyze`, `flutter test`. Секрет `TEMPLATE_READ_TOKEN` — fine-grained PAT с Contents: Read на `DimaM18/mobile-template-flutter`. Kit'ы приходят оттуда с `ref: v0.1.4`. Версии идут в ногу с серверной частью: порядок для 0.1.4: сначала публикуются серверные пакеты `@dimam18/*` 0.1.4 и вливается PR в `DimaM18/SpoRand` с их подъёмом; затем здесь `tool/contract.sh sync <клон SpoRand на этом коммите>` перепиновывает `contract/SOURCE` (коммит); только потом вливается переход на kit'ы.
- `e2e.yml`: выкачивает бэкенд на закреплённом коммите, `tool/contract.sh check`, сквозной прогон. Секреты: `BACKEND_READ_TOKEN` (fine-grained PAT с Contents: Read на `DimaM18/SpoRand`), `PACKAGES_READ_TOKEN` (classic PAT с `read:packages` для пакетов `@dimam18/*`, которые собирает бэкенд; без него — `GITHUB_TOKEN`, если владелец пакетов дал этому репозиторию доступ на чтение) и `TEMPLATE_READ_TOKEN`.
