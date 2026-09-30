// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Музыкальная вечеринка';

  @override
  String get bootLabelConfig => 'Загружаем настройки…';

  @override
  String get bootLabelWarmup => 'Готовим звуки…';

  @override
  String get bootLabelSdk => 'Подключаем сервисы…';

  @override
  String get bootLabelEnter => 'Поехали!';

  @override
  String bootProgressSemantics(int percent) {
    return 'Загрузка: $percent%';
  }

  @override
  String get bootFailedTitle => 'Не получилось запуститься';

  @override
  String get bootFailedBody => 'Проверьте интернет и попробуйте ещё раз.';

  @override
  String get bootRetry => 'Попробовать снова';

  @override
  String get forceUpdateTitle => 'Пора обновиться';

  @override
  String get forceUpdateBody =>
      'Эта версия больше не поддерживается. Обновите приложение, чтобы продолжить играть.';

  @override
  String get forceUpdateAction => 'Обновить';

  @override
  String get maintenanceTitle => 'Небольшой перерыв';

  @override
  String get maintenanceBody =>
      'Мы настраиваем серверы. Скоро вернёмся — загляните через пару минут.';

  @override
  String get maintenanceRetry => 'Проверить снова';

  @override
  String get onboardingAgeTitle => 'Год рождения';

  @override
  String get onboardingAgeSubtitle =>
      'Нужен, чтобы настроить приложение под ваш возраст.';

  @override
  String get onboardingAgeFieldLabel => 'Год';

  @override
  String get onboardingAgeFieldHint => 'ГГГГ';

  @override
  String get onboardingAgeInvalid => 'Введите год из четырёх цифр';

  @override
  String get onboardingContinue => 'Продолжить';

  @override
  String get onboardingBlockedTitle => 'Пока рано';

  @override
  String get onboardingBlockedBody =>
      'Это приложение предназначено для игроков от 13 лет.';

  @override
  String get onboardingConsentTitle => 'Ваша приватность';

  @override
  String get onboardingConsentBody =>
      'Мы не передаём вашу музыку в аналитику и рекламу. Можно помочь нам улучшать игру анонимной статистикой — это по желанию, и выбор можно поменять в настройках.';

  @override
  String get onboardingConsentAnalytics => 'Отправлять анонимную статистику';

  @override
  String get onboardingConsentMinorNote =>
      'Для игроков младше 16 лет статистика отключена.';

  @override
  String get onboardingConsentStart => 'Начать игру';

  @override
  String get homeHeadline => 'Чья это песня?';

  @override
  String get homeSubtitle =>
      'Игра для компании: слушаем фрагмент и угадываем быстрее всех.';

  @override
  String get homeCreateRoom => 'Создать комнату';

  @override
  String get homeJoinTitle => 'Есть код комнаты?';

  @override
  String get homeJoinCodeLabel => 'Код из 6 символов';

  @override
  String get homeJoinAction => 'Войти';

  @override
  String get homeJoinCodeInvalid => 'Код состоит из 6 букв и цифр';

  @override
  String get homeRemoveAds => 'Играть без рекламы';

  @override
  String get homeSettingsTooltip => 'Настройки';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsPrivacySection => 'Приватность';

  @override
  String get settingsAnalyticsTitle => 'Анонимная статистика';

  @override
  String get settingsAnalyticsSubtitle =>
      'Помогает находить ошибки и улучшать игру';

  @override
  String get settingsAnalyticsUnavailable =>
      'Недоступно для игроков младше 16 лет';

  @override
  String get settingsPrivacyOptions => 'Реклама и согласия';

  @override
  String get settingsPurchasesSection => 'Покупки';

  @override
  String get settingsRemoveAds => 'Убрать рекламу';

  @override
  String get settingsRestorePurchases => 'Восстановить покупки';

  @override
  String get settingsRestoreDone => 'Покупки восстановлены';

  @override
  String get settingsRestoreNothing => 'Покупок не найдено';

  @override
  String get settingsRestoreFailed => 'Не удалось восстановить покупки';

  @override
  String get settingsAboutSection => 'О приложении';

  @override
  String settingsVersion(String version) {
    return 'Версия $version';
  }

  @override
  String settingsDegraded(String steps) {
    return 'Ограниченный режим: $steps';
  }

  @override
  String get settingsTerms => 'Условия использования';

  @override
  String get settingsPrivacyPolicy => 'Политика конфиденциальности';

  @override
  String get paywallTitle => 'Играйте без границ';

  @override
  String get paywallSubtitle =>
      'Больше раундов, больше друзей, никакой рекламы.';

  @override
  String get paywallPerkNoAds => 'Без рекламы после игры';

  @override
  String get paywallPerkRounds => 'До 50 раундов в игре';

  @override
  String get paywallPerkPlayers => 'До 12 игроков в комнате';

  @override
  String get paywallRemoveAds => 'Без рекламы';

  @override
  String paywallRemoveAdsDetail(String price) {
    return 'Разовая покупка — $price';
  }

  @override
  String get paywallPremiumMonthly => 'Premium на месяц';

  @override
  String get paywallPremiumYearly => 'Premium на год';

  @override
  String paywallPerMonth(String price) {
    return '$price в месяц';
  }

  @override
  String paywallPerYear(String price) {
    return '$price в год';
  }

  @override
  String paywallTrial(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня бесплатно',
      many: '$days дней бесплатно',
      few: '$days дня бесплатно',
      one: '$days день бесплатно',
    );
    return '$_temp0';
  }

  @override
  String get paywallBuy => 'Продолжить';

  @override
  String get paywallRestore => 'Восстановить покупки';

  @override
  String get paywallLegal =>
      'Подписка продлевается автоматически, если не отменить её в настройках магазина не позднее чем за 24 часа до конца периода. Оплата списывается с аккаунта магазина.';

  @override
  String get paywallUnavailable => 'Покупки сейчас недоступны';

  @override
  String get paywallLoadFailed => 'Не удалось загрузить предложения';

  @override
  String get paywallRetry => 'Повторить';

  @override
  String get paywallPurchased => 'Готово! Спасибо за поддержку';

  @override
  String get paywallPending => 'Покупка ожидает подтверждения';

  @override
  String get paywallFailed => 'Покупка не прошла';

  @override
  String get paywallOwned => 'Уже куплено';

  @override
  String get placeholderBody => 'Этот экран появится в следующей сборке.';

  @override
  String joinTitle(String code) {
    return 'Комната $code';
  }

  @override
  String get notFoundTitle => 'Страница не найдена';

  @override
  String get notFoundAction => 'На главную';

  @override
  String get createRoomTitle => 'Новая комната';

  @override
  String get createRoomModeLabel => 'Режим игры';

  @override
  String get modeWhoseSong => 'Чья это песня?';

  @override
  String get modeWhoseSongHint => 'Угадайте, из чьей музыки фрагмент';

  @override
  String get modeGuessTrack => 'Угадай трек';

  @override
  String get modeGuessTrackHint => 'Четыре варианта — назовите песню';

  @override
  String get displayNameLabel => 'Ваше имя в игре';

  @override
  String get displayNameInvalid => 'От 2 до 20 символов';

  @override
  String get createRoomAction => 'Создать комнату';

  @override
  String get joinSubtitle => 'Как вас называть в игре?';

  @override
  String get joinAction => 'Войти в комнату';

  @override
  String get roomErrorNotFound => 'Комната не найдена. Проверьте код';

  @override
  String get roomErrorFull => 'В комнате нет свободных мест';

  @override
  String get roomErrorLocked => 'Игра уже началась — дождитесь итогов';

  @override
  String get roomErrorRateLimited => 'Слишком много попыток. Подождите минуту';

  @override
  String get roomErrorNetwork => 'Нет связи с сервером';

  @override
  String get roomErrorOther => 'Что-то пошло не так. Попробуйте ещё раз';

  @override
  String get lobbyTitle => 'Лобби';

  @override
  String get lobbyCodeLabel => 'Код комнаты';

  @override
  String get lobbyShare => 'Пригласить';

  @override
  String get lobbyCopyLink => 'Скопировать ссылку';

  @override
  String get lobbyLinkCopied => 'Ссылка скопирована';

  @override
  String lobbyShareText(String code, String link) {
    return 'Заходи в игру! Код комнаты: $code\n$link';
  }

  @override
  String lobbyShareTextNoLink(String code) {
    return 'Заходи в игру! Код комнаты: $code';
  }

  @override
  String lobbyQrSemantics(String code) {
    return 'QR-код для входа в комнату $code';
  }

  @override
  String lobbyPlayersTitle(int count) {
    return 'Игроки: $count';
  }

  @override
  String get lobbyHostBadge => 'Ведущий';

  @override
  String get lobbyYouBadge => 'Вы';

  @override
  String get lobbyReady => 'Готов';

  @override
  String get lobbyNotReady => 'Не готов';

  @override
  String get lobbyAway => 'Переподключается';

  @override
  String get lobbyConnecting => 'Подключаемся к комнате…';

  @override
  String get lobbyReconnecting => 'Связь пропала. Переподключаемся…';

  @override
  String get lobbySettingsTitle => 'Настройки игры';

  @override
  String get lobbyRoundsLabel => 'Раундов';

  @override
  String lobbyRoundsLocked(int count) {
    return '$count раундов — в Premium';
  }

  @override
  String get lobbyStart => 'Начать игру';

  @override
  String lobbyNeedPlayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Нужно минимум $count игрока',
      many: 'Нужно минимум $count игроков',
      few: 'Нужно минимум $count игрока',
      one: 'Нужен минимум $count игрок',
    );
    return '$_temp0';
  }

  @override
  String lobbyNeedContributors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ещё $count игрокам нужно добавить свои песни',
      many: 'Ещё $count игрокам нужно добавить свои песни',
      few: 'Ещё $count игрокам нужно добавить свои песни',
      one: 'Ещё $count игроку нужно добавить свои песни',
    );
    return '$_temp0';
  }

  @override
  String get lobbyWaitingForHost => 'Ведущий скоро начнёт игру';

  @override
  String get lobbyImReady => 'Я готов';

  @override
  String get lobbyKick => 'Удалить из комнаты';

  @override
  String get lobbyReport => 'Пожаловаться';

  @override
  String get lobbyReportTitle => 'Причина жалобы';

  @override
  String get reportReasonName => 'Оскорбительное имя';

  @override
  String get reportReasonCheating => 'Жульничает';

  @override
  String get reportReasonHarassment => 'Травля или оскорбления';

  @override
  String get reportReasonSpam => 'Спам';

  @override
  String get reportReasonOther => 'Другое';

  @override
  String get lobbyReportSent => 'Жалоба отправлена. Спасибо!';

  @override
  String get lobbyReportFailed => 'Не удалось отправить жалобу';

  @override
  String get lobbyLeave => 'Выйти';

  @override
  String get lobbyLeaveConfirmTitle => 'Выйти из комнаты?';

  @override
  String get lobbyLeaveConfirmBody =>
      'Вернуться можно по тому же коду, пока игра не началась.';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonLoading => 'Загрузка…';

  @override
  String get lobbyNoRoom => 'Вы не в комнате';

  @override
  String get lobbyBackHome => 'На главную';

  @override
  String get roomEndedKicked => 'Ведущий удалил вас из комнаты';

  @override
  String get roomEndedClosed => 'Комната закрыта';

  @override
  String get roomEndedReplaced => 'Вы открыли эту комнату на другом устройстве';

  @override
  String get roomEndedVersion => 'Обновите приложение, чтобы играть';

  @override
  String get roomEndedLost => 'Не удалось восстановить связь с комнатой';

  @override
  String get errorNotHost => 'Это может сделать только ведущий';

  @override
  String get errorPoolInsufficient => 'Игрокам не хватает песен для игры';

  @override
  String get errorTierRequired => 'Для этой настройки нужен Premium';

  @override
  String get errorPlaybackUnavailable =>
      'Телефон ведущего не может включить музыку';

  @override
  String get errorInvalidState => 'Сейчас это сделать нельзя';

  @override
  String get errorRateLimited => 'Слишком быстро. Подождите секунду';

  @override
  String get errorGeneric => 'Что-то пошло не так';

  @override
  String get gameWaiting => 'Ждём начала игры…';

  @override
  String get gameStartingTitle => 'Приготовьтесь!';

  @override
  String gameStartingRounds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count раунда',
      many: '$count раундов',
      few: '$count раунда',
      one: '$count раунд',
    );
    return '$_temp0';
  }

  @override
  String gameRoundOf(int current, int total) {
    return 'Раунд $current из $total';
  }

  @override
  String get gameBonusRound => 'Бонусный раунд';

  @override
  String get gamePromptWhoseSong => 'Чья это песня?';

  @override
  String get gamePromptGuessTrack => 'Что за трек?';

  @override
  String get gameListen => 'Слушайте…';

  @override
  String get gameTapFast => 'Жмите быстрее всех!';

  @override
  String get gameYourTrack => 'Это твой трек!';

  @override
  String get gameYourTrackHint => 'Смотрите, кто угадает';

  @override
  String get gameAnswerSent => 'Ответ отправлен';

  @override
  String get gameAnswerAccepted => 'Ответ принят!';

  @override
  String get gameAnswerRejected => 'Ответ не засчитан';

  @override
  String get gameTimeUp => 'Время вышло';

  @override
  String gameProgress(int answered, int eligible) {
    return 'Ответили $answered из $eligible';
  }

  @override
  String get gameAirplayWarning =>
      'AirPlay задерживает звук примерно на 2 секунды. Лучше включить динамик телефона.';

  @override
  String revealCorrect(int points) {
    return 'Верно! +$points';
  }

  @override
  String get revealWrong => 'Мимо';

  @override
  String get revealNoAnswer => 'Без ответа';

  @override
  String get revealOwnerYou => 'Это был ваш трек';

  @override
  String revealReaction(String seconds) {
    return 'Реакция: $seconds с';
  }

  @override
  String revealOwner(String names) {
    return 'Это трек: $names';
  }

  @override
  String revealAnswer(String label) {
    return 'Ответ: $label';
  }

  @override
  String get revealStandings => 'Таблица';

  @override
  String revealGained(int points) {
    return '+$points';
  }

  @override
  String pointsShort(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points очка',
      many: '$points очков',
      few: '$points очка',
      one: '$points очко',
    );
    return '$_temp0';
  }

  @override
  String get gameVoided => 'Раунд отменён — сыграем запасной';

  @override
  String get gameVoidedPlayback => 'Не получилось включить музыку';

  @override
  String get gameVoidedHost => 'Ведущий отключился';

  @override
  String get gameVoidedServer => 'Сервер перезапустился';

  @override
  String get gamePaused => 'Ждём ведущего…';

  @override
  String get gamePausedHint => 'Игра продолжится, когда он вернётся';

  @override
  String get bonusOfferTitle => 'Посмотри рекламу — +1 раунд для всех';

  @override
  String get bonusOfferAction => 'Смотреть';

  @override
  String get bonusOfferWaiting =>
      'Бонусный раунд? Кто-то может посмотреть рекламу';

  @override
  String bonusSponsorWatching(String name) {
    return '$name смотрит рекламу…';
  }

  @override
  String get bonusYouWatching => 'Готовим рекламу…';

  @override
  String get bonusVerifying => 'Проверяем награду…';

  @override
  String bonusGranted(String name) {
    return '+1 раунд для всех! Спасибо, $name';
  }

  @override
  String get bonusCancelled => 'Бонусного раунда не будет';

  @override
  String get bonusCancelledSsv => 'Не удалось подтвердить просмотр. Извините!';

  @override
  String get adBreakCounting => 'Считаем очки…';

  @override
  String get upsellTitle => 'Играть без рекламы';

  @override
  String upsellPrice(String price) {
    return 'Играть без рекламы — $price';
  }

  @override
  String get upsellAction => 'Подробнее';

  @override
  String get resultsTitle => 'Итоги';

  @override
  String get resultsPlayAgain => 'Сыграть ещё';

  @override
  String get resultsWaitingHost => 'Ведущий может начать новую игру';

  @override
  String resultsRounds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сыграно $count раунда',
      many: 'Сыграно $count раундов',
      few: 'Сыграно $count раунда',
      one: 'Сыгран $count раунд',
    );
    return '$_temp0';
  }

  @override
  String get resultsBonusUsed => 'С бонусным раундом';

  @override
  String resultsCorrect(int count) {
    return 'Верно: $count';
  }

  @override
  String get debugClockTitle => 'Калибровка часов';

  @override
  String get debugClockHint =>
      'Нажимайте на область несколько раз. Тест проверяет, что время касаний и кадров идёт по часам устройства.';

  @override
  String get debugClockTapArea => 'Нажмите здесь';

  @override
  String debugClockPassed(int count) {
    return 'Часы совпадают ($count замеров)';
  }

  @override
  String debugClockFailed(int count) {
    return 'Часы НЕ совпадают ($count замеров)';
  }

  @override
  String get debugClockCopy => 'Скопировать отчёт';

  @override
  String get debugClockClear => 'Очистить';

  @override
  String get settingsClockCalibration => 'Калибровка часов (для разработчиков)';

  @override
  String get gameDjStarting => 'Ведущий включает песню…';

  @override
  String get gameDjCueTitle =>
      'Включи эту песню в своём музыкальном приложении';

  @override
  String get gameDjCueSecret =>
      'Название видишь только ты — не показывай экран';

  @override
  String get gameDjOpenApp => 'Открыть в музыкальном приложении';

  @override
  String get gameDjOpenAppFailed =>
      'Не получилось открыть приложение — найдите песню вручную';

  @override
  String get gameDjMusicPlaying => 'Музыка играет!';

  @override
  String get gameDjMusicPlayingHint => 'Нажмите, как только песня зазвучит';

  @override
  String get gameDjWatchingTitle => 'Вы диджей!';

  @override
  String get gameDjWatchingHint => 'В этом раунде отвечают гости';

  @override
  String get gameAnswerRejectedDj => 'Диджей в этом раунде не отвечает';

  @override
  String get gameTextRoundHint => 'Раунд без музыки: читаем и угадываем';

  @override
  String get gameTextRoundLocked => 'Приготовьтесь…';

  @override
  String get homeMySongs => 'Мои песни';

  @override
  String get mySongsTitle => 'Мои песни';

  @override
  String get mySongsSearchLabel => 'Песня или исполнитель';

  @override
  String get mySongsSearchEmpty => 'Ничего не нашлось';

  @override
  String get mySongsSearchFailed => 'Поиск не сработал. Проверьте интернет.';

  @override
  String mySongsSelected(int count, int max) {
    return 'Выбрано $count из $max';
  }

  @override
  String mySongsNeedMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Добавьте ещё $count песни',
      many: 'Добавьте ещё $count песен',
      few: 'Добавьте ещё $count песни',
      one: 'Добавьте ещё $count песню',
    );
    return '$_temp0';
  }

  @override
  String mySongsFull(int max) {
    return 'Можно выбрать не больше $max песен';
  }

  @override
  String get mySongsSave => 'Сохранить';

  @override
  String get mySongsSaved => 'Песни сохранены';

  @override
  String get mySongsSaveFailed => 'Не получилось сохранить';

  @override
  String get mySongsLoadFailed => 'Не получилось загрузить ваши песни';

  @override
  String mySongsEmpty(int min, int max) {
    return 'Найдите от $min до $max любимых песен — друзья будут угадывать, чьи они';
  }

  @override
  String get mySongsAdd => 'Добавить';

  @override
  String get mySongsRemove => 'Убрать';

  @override
  String get mySongsPreviewTitle => 'Что увидят друзья';

  @override
  String get mySongsPreviewBody =>
      'Если в игре выпадет ваша песня, все увидят её название, исполнителя и что она ваша. Весь список целиком не увидит никто.';

  @override
  String get lobbyAddMySongs => 'Добавить мои песни';

  @override
  String get lobbyUpdateMySongs => 'Обновить мои песни';

  @override
  String get lobbyOpenMySongs => 'Открыть «Мои песни»';

  @override
  String get lobbyPoolConsentBody =>
      'Эти песни будут показаны комнате как ваши';

  @override
  String get lobbyPoolConsentConfirm => 'Подтвердить';

  @override
  String get lobbyPoolSent => 'Ваши песни в игре';

  @override
  String get lobbyPoolFailed => 'Не получилось добавить песни';

  @override
  String lobbyPoolNeedPicks(int min) {
    return 'Сначала выберите хотя бы $min песен в «Мои песни»';
  }

  @override
  String lobbyPoolTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count песни',
      many: '$count песен',
      few: '$count песни',
      one: '$count песня',
    );
    return '$_temp0';
  }

  @override
  String lobbyPoolTooSmall(String name, int min) {
    return 'У $name меньше $min песен';
  }

  @override
  String get lobbyNeedAnyPool =>
      'Хотя бы одному игроку нужно добавить свои песни';

  @override
  String get lobbyDjHint =>
      'Вы диджей: включайте песни в своём музыкальном приложении, на колонке погромче';

  @override
  String get mySongsLegacyHint =>
      'Песни из старого каталога нужно заменить новыми';

  @override
  String get modeEmojiQuiz => 'Угадай песню';

  @override
  String get modeEmojiQuizHint => 'Угадайте песню по эмодзи — музыка не нужна';

  @override
  String get gamePromptEmoji => 'Какая это песня?';

  @override
  String get gameEmojiHidden => 'Эмодзи появятся на старте';

  @override
  String gameEmojiSemantics(String emoji) {
    return 'Эмодзи: $emoji';
  }

  @override
  String revealYear(String year) {
    return 'Год: $year';
  }

  @override
  String gameDjStartingNamed(String name) {
    return '$name включает песню…';
  }

  @override
  String get gameDjRoundNoAnswer => 'Ты DJ этого раунда — отвечают остальные';

  @override
  String gameVoidedNotice(String reason) {
    return 'Раунд пропущен: $reason';
  }

  @override
  String get gameVoidedNoticeNoReason => 'Раунд пропущен';

  @override
  String get lobbyCanDj => 'Могу включать музыку';

  @override
  String get lobbyCanDjHint =>
      'Иногда DJ будешь ты: включишь песню в своём музыкальном приложении';

  @override
  String get lobbyDjBadge => 'DJ';

  @override
  String get lobbyEmojiMarkets => 'Какие песни';

  @override
  String get lobbyEmojiMarketIntl => 'Международные';

  @override
  String get lobbyEmojiMarketPl => 'Польские';

  @override
  String get lobbyEmojiDifficulty => 'Сложность';

  @override
  String get lobbyEmojiDifficultyEasy => 'Лёгкие';

  @override
  String get lobbyEmojiDifficultyMedium => 'До средних';

  @override
  String get lobbyEmojiDifficultyHard => 'Все, включая сложные';

  @override
  String get lobbyEmojiHint => 'Без музыки: хватит телефонов';

  @override
  String gameYouTubePressPlay(String playIcon) {
    return 'Нажми $playIcon в плеере. Если YouTube сначала покажет рекламу, дождись песни';
  }

  @override
  String get gameYouTubePlayButton => 'кнопку воспроизведения';

  @override
  String get gameYouTubeConsentTitle => 'Включить плеер YouTube?';

  @override
  String get gameYouTubeConsentBody =>
      'Песня сыграет в официальном плеере YouTube. Когда он загружается, YouTube (Google) получает данные о твоём устройстве и может показать рекламу.';

  @override
  String get gameYouTubeConsentAllow => 'Разрешить';

  @override
  String get gameYouTubeConsentDecline => 'Нет, включу сам';

  @override
  String get gameYouTubeFallback => 'Видео не играет — включи песню сам';

  @override
  String get gameYouTubeWindowTooSmall =>
      'Окно слишком маленькое для плеера YouTube. Разверни его или включи песню сам';

  @override
  String get gameYouTubeDeclined =>
      'Без YouTube: включи песню в своём приложении';

  @override
  String get mySongsYouTubeAdd => 'Видео YouTube';

  @override
  String mySongsYouTubeTitle(String song) {
    return 'Видео для песни «$song»';
  }

  @override
  String get mySongsYouTubeHint =>
      'Вставь ссылку на официальное видео песни — когда ты DJ, она сыграет в плеере YouTube';

  @override
  String get mySongsYouTubeField => 'Ссылка на YouTube';

  @override
  String get mySongsYouTubePaste => 'Вставить';

  @override
  String get mySongsYouTubeCheck => 'Проверить';

  @override
  String get mySongsYouTubeUse => 'Привязать';

  @override
  String get mySongsYouTubeCancel => 'Отмена';

  @override
  String get mySongsYouTubeRemove => 'Убрать видео';

  @override
  String get mySongsYouTubeInvalid => 'Это не ссылка на видео YouTube';

  @override
  String get mySongsYouTubeNotFound => 'Видео не найдено или скрыто';

  @override
  String get mySongsYouTubeNotEmbeddable =>
      'Автор запретил показывать это видео в приложениях';

  @override
  String get mySongsYouTubeFailed => 'Не получилось проверить ссылку';

  @override
  String get mySongsYouTubeLinked => 'Видео YouTube привязано';

  @override
  String mySongsYouTubeChannel(String channel) {
    return 'Канал: $channel';
  }

  @override
  String get gameMarkerCircle => 'Круг';

  @override
  String get gameMarkerTriangle => 'Треугольник';

  @override
  String get gameMarkerSquare => 'Квадрат';

  @override
  String get gameMarkerDiamond => 'Ромб';

  @override
  String get gameMarkerHexagon => 'Шестиугольник';

  @override
  String get gameMarkerStar => 'Звезда';

  @override
  String gameAnswerSemantics(String marker, String option) {
    return '$marker: $option';
  }

  @override
  String get gameYourPick => 'Твой ответ';

  @override
  String get gameTileCorrect => 'Верно';

  @override
  String gameTimeLeftSemantics(int seconds) {
    return 'Осталось $seconds с';
  }

  @override
  String revealStreak(int count) {
    return 'Серия ×$count';
  }

  @override
  String get playerBadgeHost => 'Ведущий';

  @override
  String get playerBadgeDj => 'DJ';

  @override
  String get playerBadgeReady => 'Готов';

  @override
  String get gameDjTapped => 'Отмечено';

  @override
  String get gameLeaveInlineConfirm => 'Выйти из игры?';

  @override
  String get gameLeaveInlineCancel => 'Остаться';

  @override
  String get lobbyCopyCode => 'Скопировать код';

  @override
  String get lobbyCodeCopied => 'Код скопирован';

  @override
  String onboardingStepSemantics(int step, int total) {
    return 'Шаг $step из $total';
  }

  @override
  String standingsMovedUp(int n) {
    return 'вверх на $n';
  }

  @override
  String standingsMovedDown(int n) {
    return 'вниз на $n';
  }

  @override
  String resultsPodiumSemantics(int rank, String name, String points) {
    return '$rank место: $name, $points';
  }
}
