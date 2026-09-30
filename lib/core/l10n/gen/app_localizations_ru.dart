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
}
