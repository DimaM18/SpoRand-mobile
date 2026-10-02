import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('en'),
    Locale('pl'),
  ];

  /// Working title shown in the app switcher. TODO(owner): replace with the chosen brand (brief Q3). Never use 'Spotify' or a 'Spo' prefix.
  ///
  /// In ru, this message translates to:
  /// **'Музыкальная вечеринка'**
  String get appTitle;

  /// Splash label while the config stage runs.
  ///
  /// In ru, this message translates to:
  /// **'Загружаем настройки…'**
  String get bootLabelConfig;

  /// Splash label while resources warm up.
  ///
  /// In ru, this message translates to:
  /// **'Готовим звуки…'**
  String get bootLabelWarmup;

  /// Splash label while SDKs initialize.
  ///
  /// In ru, this message translates to:
  /// **'Подключаем сервисы…'**
  String get bootLabelSdk;

  /// Splash label right before entering the app.
  ///
  /// In ru, this message translates to:
  /// **'Поехали!'**
  String get bootLabelEnter;

  /// Screen reader value of the splash progress ring.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка: {percent}%'**
  String bootProgressSemantics(int percent);

  /// No description provided for @bootFailedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось запуститься'**
  String get bootFailedTitle;

  /// No description provided for @bootFailedBody.
  ///
  /// In ru, this message translates to:
  /// **'Проверь интернет и попробуй ещё раз.'**
  String get bootFailedBody;

  /// No description provided for @bootRetry.
  ///
  /// In ru, this message translates to:
  /// **'Попробовать снова'**
  String get bootRetry;

  /// No description provided for @forceUpdateTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пора обновиться'**
  String get forceUpdateTitle;

  /// No description provided for @forceUpdateBody.
  ///
  /// In ru, this message translates to:
  /// **'Эта версия больше не поддерживается. Обнови приложение, чтобы продолжить играть.'**
  String get forceUpdateBody;

  /// No description provided for @forceUpdateAction.
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get forceUpdateAction;

  /// No description provided for @maintenanceTitle.
  ///
  /// In ru, this message translates to:
  /// **'Небольшой перерыв'**
  String get maintenanceTitle;

  /// No description provided for @maintenanceBody.
  ///
  /// In ru, this message translates to:
  /// **'Мы настраиваем серверы. Скоро вернёмся — загляни через пару минут.'**
  String get maintenanceBody;

  /// No description provided for @maintenanceRetry.
  ///
  /// In ru, this message translates to:
  /// **'Проверить снова'**
  String get maintenanceRetry;

  /// No description provided for @onboardingAgeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Год рождения'**
  String get onboardingAgeTitle;

  /// No description provided for @onboardingAgeSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Нужен, чтобы настроить приложение под твой возраст.'**
  String get onboardingAgeSubtitle;

  /// No description provided for @onboardingAgeFieldLabel.
  ///
  /// In ru, this message translates to:
  /// **'Год'**
  String get onboardingAgeFieldLabel;

  /// No description provided for @onboardingAgeFieldHint.
  ///
  /// In ru, this message translates to:
  /// **'ГГГГ'**
  String get onboardingAgeFieldHint;

  /// No description provided for @onboardingAgeInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Введи год из четырёх цифр'**
  String get onboardingAgeInvalid;

  /// No description provided for @onboardingContinue.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get onboardingContinue;

  /// No description provided for @onboardingBlockedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пока рано'**
  String get onboardingBlockedTitle;

  /// No description provided for @onboardingBlockedBody.
  ///
  /// In ru, this message translates to:
  /// **'Это приложение предназначено для игроков от 13 лет.'**
  String get onboardingBlockedBody;

  /// No description provided for @onboardingConsentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Твоя приватность'**
  String get onboardingConsentTitle;

  /// No description provided for @onboardingConsentBody.
  ///
  /// In ru, this message translates to:
  /// **'Мы не передаём твою музыку в аналитику и рекламу. Можно помочь нам улучшать игру анонимной статистикой — это по желанию, и выбор можно поменять в настройках.'**
  String get onboardingConsentBody;

  /// No description provided for @onboardingConsentAnalytics.
  ///
  /// In ru, this message translates to:
  /// **'Отправлять анонимную статистику'**
  String get onboardingConsentAnalytics;

  /// No description provided for @onboardingConsentMinorNote.
  ///
  /// In ru, this message translates to:
  /// **'Для игроков младше 16 лет статистика отключена.'**
  String get onboardingConsentMinorNote;

  /// No description provided for @onboardingConsentStart.
  ///
  /// In ru, this message translates to:
  /// **'Начать игру'**
  String get onboardingConsentStart;

  /// No description provided for @homeHeadline.
  ///
  /// In ru, this message translates to:
  /// **'Чья это песня?'**
  String get homeHeadline;

  /// No description provided for @homeSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Игра для компании: слушаем фрагмент и угадываем быстрее всех.'**
  String get homeSubtitle;

  /// No description provided for @homeCreateRoom.
  ///
  /// In ru, this message translates to:
  /// **'Создать комнату'**
  String get homeCreateRoom;

  /// No description provided for @homeJoinTitle.
  ///
  /// In ru, this message translates to:
  /// **'Есть код комнаты?'**
  String get homeJoinTitle;

  /// No description provided for @homeJoinCodeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Код из 6 символов'**
  String get homeJoinCodeLabel;

  /// No description provided for @homeJoinAction.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get homeJoinAction;

  /// No description provided for @homeJoinCodeInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Код состоит из 6 букв и цифр'**
  String get homeJoinCodeInvalid;

  /// No description provided for @homeRemoveAds.
  ///
  /// In ru, this message translates to:
  /// **'Играть без рекламы'**
  String get homeRemoveAds;

  /// No description provided for @homeSettingsTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get homeSettingsTooltip;

  /// No description provided for @settingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settingsTitle;

  /// No description provided for @settingsPrivacySection.
  ///
  /// In ru, this message translates to:
  /// **'Приватность'**
  String get settingsPrivacySection;

  /// No description provided for @settingsAnalyticsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Анонимная статистика'**
  String get settingsAnalyticsTitle;

  /// No description provided for @settingsAnalyticsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Помогает находить ошибки и улучшать игру'**
  String get settingsAnalyticsSubtitle;

  /// No description provided for @settingsAnalyticsUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Недоступно для игроков младше 16 лет'**
  String get settingsAnalyticsUnavailable;

  /// No description provided for @settingsPrivacyOptions.
  ///
  /// In ru, this message translates to:
  /// **'Реклама и согласия'**
  String get settingsPrivacyOptions;

  /// No description provided for @settingsPurchasesSection.
  ///
  /// In ru, this message translates to:
  /// **'Покупки'**
  String get settingsPurchasesSection;

  /// No description provided for @settingsRemoveAds.
  ///
  /// In ru, this message translates to:
  /// **'Убрать рекламу'**
  String get settingsRemoveAds;

  /// No description provided for @settingsRestorePurchases.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить покупки'**
  String get settingsRestorePurchases;

  /// No description provided for @settingsRestoreDone.
  ///
  /// In ru, this message translates to:
  /// **'Покупки восстановлены'**
  String get settingsRestoreDone;

  /// No description provided for @settingsRestoreNothing.
  ///
  /// In ru, this message translates to:
  /// **'Покупок не найдено'**
  String get settingsRestoreNothing;

  /// No description provided for @settingsRestoreFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось восстановить покупки'**
  String get settingsRestoreFailed;

  /// No description provided for @settingsAboutSection.
  ///
  /// In ru, this message translates to:
  /// **'О приложении'**
  String get settingsAboutSection;

  /// No description provided for @settingsVersion.
  ///
  /// In ru, this message translates to:
  /// **'Версия {version}'**
  String settingsVersion(String version);

  /// Shown when some boot steps degraded; steps is a technical list of step ids.
  ///
  /// In ru, this message translates to:
  /// **'Ограниченный режим: {steps}'**
  String settingsDegraded(String steps);

  /// No description provided for @settingsTerms.
  ///
  /// In ru, this message translates to:
  /// **'Условия использования'**
  String get settingsTerms;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In ru, this message translates to:
  /// **'Политика конфиденциальности'**
  String get settingsPrivacyPolicy;

  /// No description provided for @paywallTitle.
  ///
  /// In ru, this message translates to:
  /// **'Играй без границ'**
  String get paywallTitle;

  /// No description provided for @paywallSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Больше раундов, больше друзей, никакой рекламы.'**
  String get paywallSubtitle;

  /// No description provided for @paywallPerkNoAds.
  ///
  /// In ru, this message translates to:
  /// **'Без рекламы после игры'**
  String get paywallPerkNoAds;

  /// No description provided for @paywallPerkRounds.
  ///
  /// In ru, this message translates to:
  /// **'До 50 раундов в игре'**
  String get paywallPerkRounds;

  /// No description provided for @paywallPerkPlayers.
  ///
  /// In ru, this message translates to:
  /// **'До 12 игроков в комнате'**
  String get paywallPerkPlayers;

  /// No description provided for @paywallRemoveAds.
  ///
  /// In ru, this message translates to:
  /// **'Без рекламы'**
  String get paywallRemoveAds;

  /// No description provided for @paywallRemoveAdsDetail.
  ///
  /// In ru, this message translates to:
  /// **'Разовая покупка — {price}'**
  String paywallRemoveAdsDetail(String price);

  /// No description provided for @paywallPremiumMonthly.
  ///
  /// In ru, this message translates to:
  /// **'Premium на месяц'**
  String get paywallPremiumMonthly;

  /// No description provided for @paywallPremiumYearly.
  ///
  /// In ru, this message translates to:
  /// **'Premium на год'**
  String get paywallPremiumYearly;

  /// No description provided for @paywallPerMonth.
  ///
  /// In ru, this message translates to:
  /// **'{price} в месяц'**
  String paywallPerMonth(String price);

  /// No description provided for @paywallPerYear.
  ///
  /// In ru, this message translates to:
  /// **'{price} в год'**
  String paywallPerYear(String price);

  /// No description provided for @paywallTrial.
  ///
  /// In ru, this message translates to:
  /// **'{days, plural, one{{days} день бесплатно} few{{days} дня бесплатно} many{{days} дней бесплатно} other{{days} дня бесплатно}}'**
  String paywallTrial(int days);

  /// No description provided for @paywallBuy.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get paywallBuy;

  /// No description provided for @paywallRestore.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить покупки'**
  String get paywallRestore;

  /// No description provided for @paywallLegal.
  ///
  /// In ru, this message translates to:
  /// **'Подписка продлевается автоматически, если не отменить её в настройках магазина не позднее чем за 24 часа до конца периода. Оплата списывается с аккаунта магазина.'**
  String get paywallLegal;

  /// No description provided for @paywallUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Покупки сейчас недоступны'**
  String get paywallUnavailable;

  /// No description provided for @paywallLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить предложения'**
  String get paywallLoadFailed;

  /// No description provided for @paywallRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get paywallRetry;

  /// No description provided for @paywallPurchased.
  ///
  /// In ru, this message translates to:
  /// **'Готово! Спасибо за поддержку'**
  String get paywallPurchased;

  /// No description provided for @paywallPending.
  ///
  /// In ru, this message translates to:
  /// **'Покупка ожидает подтверждения'**
  String get paywallPending;

  /// No description provided for @paywallFailed.
  ///
  /// In ru, this message translates to:
  /// **'Покупка не прошла'**
  String get paywallFailed;

  /// No description provided for @paywallOwned.
  ///
  /// In ru, this message translates to:
  /// **'Уже куплено'**
  String get paywallOwned;

  /// No description provided for @placeholderBody.
  ///
  /// In ru, this message translates to:
  /// **'Этот экран появится в следующей сборке.'**
  String get placeholderBody;

  /// No description provided for @joinTitle.
  ///
  /// In ru, this message translates to:
  /// **'Комната {code}'**
  String joinTitle(String code);

  /// No description provided for @notFoundTitle.
  ///
  /// In ru, this message translates to:
  /// **'Страница не найдена'**
  String get notFoundTitle;

  /// No description provided for @notFoundAction.
  ///
  /// In ru, this message translates to:
  /// **'На главную'**
  String get notFoundAction;

  /// No description provided for @createRoomTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новая комната'**
  String get createRoomTitle;

  /// No description provided for @createRoomModeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Режим игры'**
  String get createRoomModeLabel;

  /// No description provided for @modeWhoseSong.
  ///
  /// In ru, this message translates to:
  /// **'Чья это песня?'**
  String get modeWhoseSong;

  /// No description provided for @modeWhoseSongHint.
  ///
  /// In ru, this message translates to:
  /// **'Угадай, из чьей музыки фрагмент'**
  String get modeWhoseSongHint;

  /// No description provided for @modeGuessTrack.
  ///
  /// In ru, this message translates to:
  /// **'Угадай трек'**
  String get modeGuessTrack;

  /// No description provided for @modeGuessTrackHint.
  ///
  /// In ru, this message translates to:
  /// **'Четыре варианта — назови песню'**
  String get modeGuessTrackHint;

  /// No description provided for @displayNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Твоё имя в игре'**
  String get displayNameLabel;

  /// No description provided for @displayNameInvalid.
  ///
  /// In ru, this message translates to:
  /// **'От 2 до 20 символов'**
  String get displayNameInvalid;

  /// No description provided for @createRoomAction.
  ///
  /// In ru, this message translates to:
  /// **'Создать комнату'**
  String get createRoomAction;

  /// No description provided for @joinSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Как тебя называть в игре?'**
  String get joinSubtitle;

  /// No description provided for @joinAction.
  ///
  /// In ru, this message translates to:
  /// **'Войти в комнату'**
  String get joinAction;

  /// No description provided for @roomErrorNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Комната не найдена. Проверь код'**
  String get roomErrorNotFound;

  /// No description provided for @roomErrorFull.
  ///
  /// In ru, this message translates to:
  /// **'В комнате нет свободных мест'**
  String get roomErrorFull;

  /// No description provided for @roomErrorLocked.
  ///
  /// In ru, this message translates to:
  /// **'Игра уже началась — дождись итогов'**
  String get roomErrorLocked;

  /// No description provided for @roomErrorRateLimited.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много попыток. Подожди минуту'**
  String get roomErrorRateLimited;

  /// No description provided for @roomErrorNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с сервером'**
  String get roomErrorNetwork;

  /// No description provided for @roomErrorOther.
  ///
  /// In ru, this message translates to:
  /// **'Что-то пошло не так. Попробуй ещё раз'**
  String get roomErrorOther;

  /// No description provided for @lobbyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Лобби'**
  String get lobbyTitle;

  /// No description provided for @lobbyCodeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Код комнаты'**
  String get lobbyCodeLabel;

  /// No description provided for @lobbyShare.
  ///
  /// In ru, this message translates to:
  /// **'Пригласить'**
  String get lobbyShare;

  /// No description provided for @lobbyCopyLink.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать ссылку'**
  String get lobbyCopyLink;

  /// No description provided for @lobbyLinkCopied.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка скопирована'**
  String get lobbyLinkCopied;

  /// No description provided for @lobbyShareText.
  ///
  /// In ru, this message translates to:
  /// **'Заходи в игру! Код комнаты: {code}\n{link}'**
  String lobbyShareText(String code, String link);

  /// No description provided for @lobbyShareTextNoLink.
  ///
  /// In ru, this message translates to:
  /// **'Заходи в игру! Код комнаты: {code}'**
  String lobbyShareTextNoLink(String code);

  /// No description provided for @lobbyQrSemantics.
  ///
  /// In ru, this message translates to:
  /// **'QR-код для входа в комнату {code}'**
  String lobbyQrSemantics(String code);

  /// No description provided for @lobbyPlayersTitle.
  ///
  /// In ru, this message translates to:
  /// **'Игроки: {count}'**
  String lobbyPlayersTitle(int count);

  /// No description provided for @lobbyHostBadge.
  ///
  /// In ru, this message translates to:
  /// **'Ведущий'**
  String get lobbyHostBadge;

  /// No description provided for @lobbyYouBadge.
  ///
  /// In ru, this message translates to:
  /// **'Ты'**
  String get lobbyYouBadge;

  /// No description provided for @lobbyReady.
  ///
  /// In ru, this message translates to:
  /// **'На старте'**
  String get lobbyReady;

  /// No description provided for @lobbyNotReady.
  ///
  /// In ru, this message translates to:
  /// **'Не на старте'**
  String get lobbyNotReady;

  /// No description provided for @lobbyAway.
  ///
  /// In ru, this message translates to:
  /// **'Переподключается'**
  String get lobbyAway;

  /// No description provided for @lobbyConnecting.
  ///
  /// In ru, this message translates to:
  /// **'Подключаемся к комнате…'**
  String get lobbyConnecting;

  /// No description provided for @lobbyReconnecting.
  ///
  /// In ru, this message translates to:
  /// **'Связь пропала. Переподключаемся…'**
  String get lobbyReconnecting;

  /// No description provided for @lobbySettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки игры'**
  String get lobbySettingsTitle;

  /// No description provided for @lobbyRoundsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Раундов'**
  String get lobbyRoundsLabel;

  /// No description provided for @lobbyRoundsLocked.
  ///
  /// In ru, this message translates to:
  /// **'{count} раундов — в Premium'**
  String lobbyRoundsLocked(int count);

  /// No description provided for @lobbyStart.
  ///
  /// In ru, this message translates to:
  /// **'Начать игру'**
  String get lobbyStart;

  /// No description provided for @lobbyNeedPlayers.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Нужен минимум {count} игрок} few{Нужно минимум {count} игрока} many{Нужно минимум {count} игроков} other{Нужно минимум {count} игрока}}'**
  String lobbyNeedPlayers(int count);

  /// No description provided for @lobbyNeedContributors.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Ещё {count} игроку нужно добавить свои песни} few{Ещё {count} игрокам нужно добавить свои песни} many{Ещё {count} игрокам нужно добавить свои песни} other{Ещё {count} игрокам нужно добавить свои песни}}'**
  String lobbyNeedContributors(int count);

  /// No description provided for @lobbyWaitingForHost.
  ///
  /// In ru, this message translates to:
  /// **'Ведущий скоро начнёт игру'**
  String get lobbyWaitingForHost;

  /// No description provided for @lobbyImReady.
  ///
  /// In ru, this message translates to:
  /// **'Я на старте'**
  String get lobbyImReady;

  /// No description provided for @lobbyKick.
  ///
  /// In ru, this message translates to:
  /// **'Удалить из комнаты'**
  String get lobbyKick;

  /// No description provided for @lobbyReport.
  ///
  /// In ru, this message translates to:
  /// **'Пожаловаться'**
  String get lobbyReport;

  /// No description provided for @lobbyReportTitle.
  ///
  /// In ru, this message translates to:
  /// **'Причина жалобы'**
  String get lobbyReportTitle;

  /// No description provided for @reportReasonName.
  ///
  /// In ru, this message translates to:
  /// **'Оскорбительное имя'**
  String get reportReasonName;

  /// No description provided for @reportReasonCheating.
  ///
  /// In ru, this message translates to:
  /// **'Жульничает'**
  String get reportReasonCheating;

  /// No description provided for @reportReasonHarassment.
  ///
  /// In ru, this message translates to:
  /// **'Травля или оскорбления'**
  String get reportReasonHarassment;

  /// No description provided for @reportReasonSpam.
  ///
  /// In ru, this message translates to:
  /// **'Спам'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonOther.
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get reportReasonOther;

  /// No description provided for @lobbyReportSent.
  ///
  /// In ru, this message translates to:
  /// **'Жалоба отправлена. Спасибо!'**
  String get lobbyReportSent;

  /// No description provided for @lobbyReportFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отправить жалобу'**
  String get lobbyReportFailed;

  /// No description provided for @lobbyLeave.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get lobbyLeave;

  /// No description provided for @lobbyLeaveConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из комнаты?'**
  String get lobbyLeaveConfirmTitle;

  /// No description provided for @lobbyLeaveConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'Вернуться можно по тому же коду, пока игра не началась.'**
  String get lobbyLeaveConfirmBody;

  /// No description provided for @commonCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get commonCancel;

  /// No description provided for @lobbyNoRoom.
  ///
  /// In ru, this message translates to:
  /// **'Ты не в комнате'**
  String get lobbyNoRoom;

  /// No description provided for @lobbyBackHome.
  ///
  /// In ru, this message translates to:
  /// **'На главную'**
  String get lobbyBackHome;

  /// No description provided for @roomEndedKicked.
  ///
  /// In ru, this message translates to:
  /// **'Ведущий удалил тебя из комнаты'**
  String get roomEndedKicked;

  /// No description provided for @roomEndedClosed.
  ///
  /// In ru, this message translates to:
  /// **'Комната закрыта'**
  String get roomEndedClosed;

  /// No description provided for @roomEndedReplaced.
  ///
  /// In ru, this message translates to:
  /// **'Комната открыта на другом твоём устройстве'**
  String get roomEndedReplaced;

  /// No description provided for @roomEndedVersion.
  ///
  /// In ru, this message translates to:
  /// **'Обнови приложение, чтобы играть'**
  String get roomEndedVersion;

  /// No description provided for @roomEndedLost.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось восстановить связь с комнатой'**
  String get roomEndedLost;

  /// No description provided for @errorNotHost.
  ///
  /// In ru, this message translates to:
  /// **'Это может сделать только ведущий'**
  String get errorNotHost;

  /// No description provided for @errorPoolInsufficient.
  ///
  /// In ru, this message translates to:
  /// **'Игрокам не хватает песен для игры'**
  String get errorPoolInsufficient;

  /// No description provided for @errorTierRequired.
  ///
  /// In ru, this message translates to:
  /// **'Для этой настройки нужен Premium'**
  String get errorTierRequired;

  /// No description provided for @errorPlaybackUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Телефон ведущего не может включить музыку'**
  String get errorPlaybackUnavailable;

  /// No description provided for @errorInvalidState.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас это сделать нельзя'**
  String get errorInvalidState;

  /// No description provided for @errorRateLimited.
  ///
  /// In ru, this message translates to:
  /// **'Слишком быстро. Подожди секунду'**
  String get errorRateLimited;

  /// No description provided for @errorGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Что-то пошло не так'**
  String get errorGeneric;

  /// No description provided for @gameWaiting.
  ///
  /// In ru, this message translates to:
  /// **'Ждём начала игры…'**
  String get gameWaiting;

  /// No description provided for @gameStartingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Приготовься!'**
  String get gameStartingTitle;

  /// No description provided for @gameStartingRounds.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} раунд} few{{count} раунда} many{{count} раундов} other{{count} раунда}}'**
  String gameStartingRounds(int count);

  /// No description provided for @gameRoundOf.
  ///
  /// In ru, this message translates to:
  /// **'Раунд {current} из {total}'**
  String gameRoundOf(int current, int total);

  /// No description provided for @gameBonusRound.
  ///
  /// In ru, this message translates to:
  /// **'Бонусный раунд'**
  String get gameBonusRound;

  /// No description provided for @gamePromptWhoseSong.
  ///
  /// In ru, this message translates to:
  /// **'Чья это песня?'**
  String get gamePromptWhoseSong;

  /// No description provided for @gamePromptGuessTrack.
  ///
  /// In ru, this message translates to:
  /// **'Что за трек?'**
  String get gamePromptGuessTrack;

  /// No description provided for @gameListen.
  ///
  /// In ru, this message translates to:
  /// **'Слушай…'**
  String get gameListen;

  /// No description provided for @gameTapFast.
  ///
  /// In ru, this message translates to:
  /// **'Жми быстрее всех!'**
  String get gameTapFast;

  /// No description provided for @gameYourTrack.
  ///
  /// In ru, this message translates to:
  /// **'Это твой трек!'**
  String get gameYourTrack;

  /// No description provided for @gameYourTrackHint.
  ///
  /// In ru, this message translates to:
  /// **'Смотри, кто угадает'**
  String get gameYourTrackHint;

  /// No description provided for @gameAnswerSent.
  ///
  /// In ru, this message translates to:
  /// **'Ответ отправлен'**
  String get gameAnswerSent;

  /// No description provided for @gameAnswerAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Ответ принят!'**
  String get gameAnswerAccepted;

  /// No description provided for @gameAnswerRejected.
  ///
  /// In ru, this message translates to:
  /// **'Ответ не засчитан'**
  String get gameAnswerRejected;

  /// No description provided for @gameTimeUp.
  ///
  /// In ru, this message translates to:
  /// **'Время вышло'**
  String get gameTimeUp;

  /// No description provided for @gameProgress.
  ///
  /// In ru, this message translates to:
  /// **'Ответили {answered} из {eligible}'**
  String gameProgress(int answered, int eligible);

  /// No description provided for @gameAirplayWarning.
  ///
  /// In ru, this message translates to:
  /// **'AirPlay задерживает звук примерно на 2 секунды. Лучше включить динамик телефона.'**
  String get gameAirplayWarning;

  /// No description provided for @revealCorrect.
  ///
  /// In ru, this message translates to:
  /// **'Верно! +{points}'**
  String revealCorrect(int points);

  /// No description provided for @revealWrong.
  ///
  /// In ru, this message translates to:
  /// **'Мимо'**
  String get revealWrong;

  /// No description provided for @revealNoAnswer.
  ///
  /// In ru, this message translates to:
  /// **'Без ответа'**
  String get revealNoAnswer;

  /// No description provided for @revealOwnerYou.
  ///
  /// In ru, this message translates to:
  /// **'Это был твой трек'**
  String get revealOwnerYou;

  /// No description provided for @revealReaction.
  ///
  /// In ru, this message translates to:
  /// **'Реакция: {seconds} с'**
  String revealReaction(String seconds);

  /// No description provided for @revealOwner.
  ///
  /// In ru, this message translates to:
  /// **'Это трек: {names}'**
  String revealOwner(String names);

  /// No description provided for @revealAnswer.
  ///
  /// In ru, this message translates to:
  /// **'Ответ: {label}'**
  String revealAnswer(String label);

  /// No description provided for @revealStandings.
  ///
  /// In ru, this message translates to:
  /// **'Таблица'**
  String get revealStandings;

  /// No description provided for @revealGained.
  ///
  /// In ru, this message translates to:
  /// **'+{points}'**
  String revealGained(int points);

  /// No description provided for @pointsShort.
  ///
  /// In ru, this message translates to:
  /// **'{points, plural, one{{points} очко} few{{points} очка} many{{points} очков} other{{points} очка}}'**
  String pointsShort(int points);

  /// No description provided for @gameVoided.
  ///
  /// In ru, this message translates to:
  /// **'Раунд отменён — сыграем запасной'**
  String get gameVoided;

  /// No description provided for @gameVoidedPlayback.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось включить музыку'**
  String get gameVoidedPlayback;

  /// No description provided for @gameVoidedHost.
  ///
  /// In ru, this message translates to:
  /// **'Ведущий отключился'**
  String get gameVoidedHost;

  /// No description provided for @gameVoidedServer.
  ///
  /// In ru, this message translates to:
  /// **'Сервер перезапустился'**
  String get gameVoidedServer;

  /// No description provided for @gamePaused.
  ///
  /// In ru, this message translates to:
  /// **'Ждём ведущего…'**
  String get gamePaused;

  /// No description provided for @gamePausedHint.
  ///
  /// In ru, this message translates to:
  /// **'Игра продолжится, когда он вернётся'**
  String get gamePausedHint;

  /// No description provided for @bonusOfferTitle.
  ///
  /// In ru, this message translates to:
  /// **'Посмотри рекламу — +1 раунд для всех'**
  String get bonusOfferTitle;

  /// No description provided for @bonusOfferAction.
  ///
  /// In ru, this message translates to:
  /// **'Смотреть'**
  String get bonusOfferAction;

  /// No description provided for @bonusOfferWaiting.
  ///
  /// In ru, this message translates to:
  /// **'Бонусный раунд? Кто-то может посмотреть рекламу'**
  String get bonusOfferWaiting;

  /// No description provided for @bonusSponsorWatching.
  ///
  /// In ru, this message translates to:
  /// **'{name} смотрит рекламу…'**
  String bonusSponsorWatching(String name);

  /// No description provided for @bonusYouWatching.
  ///
  /// In ru, this message translates to:
  /// **'Готовим рекламу…'**
  String get bonusYouWatching;

  /// No description provided for @bonusVerifying.
  ///
  /// In ru, this message translates to:
  /// **'Проверяем награду…'**
  String get bonusVerifying;

  /// No description provided for @bonusGranted.
  ///
  /// In ru, this message translates to:
  /// **'+1 раунд для всех! Спасибо, {name}'**
  String bonusGranted(String name);

  /// No description provided for @bonusCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Бонусного раунда не будет'**
  String get bonusCancelled;

  /// No description provided for @bonusCancelledSsv.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось подтвердить просмотр. Извини!'**
  String get bonusCancelledSsv;

  /// No description provided for @adBreakCounting.
  ///
  /// In ru, this message translates to:
  /// **'Считаем очки…'**
  String get adBreakCounting;

  /// No description provided for @upsellTitle.
  ///
  /// In ru, this message translates to:
  /// **'Играть без рекламы'**
  String get upsellTitle;

  /// No description provided for @upsellPrice.
  ///
  /// In ru, this message translates to:
  /// **'Играть без рекламы — {price}'**
  String upsellPrice(String price);

  /// No description provided for @upsellAction.
  ///
  /// In ru, this message translates to:
  /// **'Подробнее'**
  String get upsellAction;

  /// No description provided for @resultsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Итоги'**
  String get resultsTitle;

  /// No description provided for @resultsPlayAgain.
  ///
  /// In ru, this message translates to:
  /// **'Сыграть ещё'**
  String get resultsPlayAgain;

  /// No description provided for @resultsWaitingHost.
  ///
  /// In ru, this message translates to:
  /// **'Ведущий может начать новую игру'**
  String get resultsWaitingHost;

  /// No description provided for @resultsRounds.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Сыгран {count} раунд} few{Сыграно {count} раунда} many{Сыграно {count} раундов} other{Сыграно {count} раунда}}'**
  String resultsRounds(int count);

  /// No description provided for @resultsBonusUsed.
  ///
  /// In ru, this message translates to:
  /// **'С бонусным раундом'**
  String get resultsBonusUsed;

  /// No description provided for @resultsCorrect.
  ///
  /// In ru, this message translates to:
  /// **'Верно: {count}'**
  String resultsCorrect(int count);

  /// No description provided for @settingsClockCalibration.
  ///
  /// In ru, this message translates to:
  /// **'Калибровка часов (для разработчиков)'**
  String get settingsClockCalibration;

  /// Guests of an external_player (BYOP) round while the DJ has not started the song yet.
  ///
  /// In ru, this message translates to:
  /// **'Ведущий включает песню…'**
  String get gameDjStarting;

  /// DJ card title (addendum A2.2). The app never plays the song itself.
  ///
  /// In ru, this message translates to:
  /// **'Включи эту песню в своём музыкальном приложении'**
  String get gameDjCueTitle;

  /// DJ card hint: only the DJ sees the title before the reveal.
  ///
  /// In ru, this message translates to:
  /// **'Название видишь только ты — не показывай экран'**
  String get gameDjCueSecret;

  /// DJ card button: hands the song to the DJ's own music app (Android play-from-search, iOS the server's hint link).
  ///
  /// In ru, this message translates to:
  /// **'Открыть в музыкальном приложении'**
  String get gameDjOpenApp;

  /// No description provided for @gameDjOpenAppFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось открыть приложение — найди песню вручную'**
  String get gameDjOpenAppFailed;

  /// The DJ taps it the moment the song starts; the touch time is the round's audio start (dj_tap).
  ///
  /// In ru, this message translates to:
  /// **'Музыка играет!'**
  String get gameDjMusicPlaying;

  /// No description provided for @gameDjMusicPlayingHint.
  ///
  /// In ru, this message translates to:
  /// **'Нажми, как только песня зазвучит'**
  String get gameDjMusicPlayingHint;

  /// guess_track: the DJ may not answer (dj_ineligible).
  ///
  /// In ru, this message translates to:
  /// **'Ты диджей!'**
  String get gameDjWatchingTitle;

  /// No description provided for @gameDjWatchingHint.
  ///
  /// In ru, this message translates to:
  /// **'В этом раунде отвечают гости'**
  String get gameDjWatchingHint;

  /// round.answer_ack with reason dj_ineligible.
  ///
  /// In ru, this message translates to:
  /// **'Диджей в этом раунде не отвечает'**
  String get gameAnswerRejectedDj;

  /// Text round (provider none): no audio.
  ///
  /// In ru, this message translates to:
  /// **'Раунд без музыки: читай и угадывай'**
  String get gameTextRoundHint;

  /// Text round before the answer buttons unlock.
  ///
  /// In ru, this message translates to:
  /// **'Приготовься…'**
  String get gameTextRoundLocked;

  /// No description provided for @homeMySongs.
  ///
  /// In ru, this message translates to:
  /// **'Мои песни'**
  String get homeMySongs;

  /// No description provided for @mySongsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Мои песни'**
  String get mySongsTitle;

  /// No description provided for @mySongsSearchLabel.
  ///
  /// In ru, this message translates to:
  /// **'Песня или исполнитель'**
  String get mySongsSearchLabel;

  /// No description provided for @mySongsSearchEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не нашлось'**
  String get mySongsSearchEmpty;

  /// No description provided for @mySongsSearchFailed.
  ///
  /// In ru, this message translates to:
  /// **'Поиск не сработал. Проверь интернет.'**
  String get mySongsSearchFailed;

  /// No description provided for @mySongsSelected.
  ///
  /// In ru, this message translates to:
  /// **'Выбрано {count} из {max}'**
  String mySongsSelected(int count, int max);

  /// No description provided for @mySongsNeedMore.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Добавь ещё {count} песню} few{Добавь ещё {count} песни} many{Добавь ещё {count} песен} other{Добавь ещё {count} песни}}'**
  String mySongsNeedMore(int count);

  /// No description provided for @mySongsFull.
  ///
  /// In ru, this message translates to:
  /// **'Можно выбрать не больше {max} песен'**
  String mySongsFull(int max);

  /// No description provided for @mySongsSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get mySongsSave;

  /// No description provided for @mySongsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Песни сохранены'**
  String get mySongsSaved;

  /// No description provided for @mySongsSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось сохранить'**
  String get mySongsSaveFailed;

  /// No description provided for @mySongsLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось загрузить твои песни'**
  String get mySongsLoadFailed;

  /// No description provided for @mySongsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Найди от {min} до {max} любимых песен — друзья будут угадывать, чьи они'**
  String mySongsEmpty(int min, int max);

  /// No description provided for @mySongsAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get mySongsAdd;

  /// No description provided for @mySongsRemove.
  ///
  /// In ru, this message translates to:
  /// **'Убрать'**
  String get mySongsRemove;

  /// Privacy preview of the pool (design doc S1.9).
  ///
  /// In ru, this message translates to:
  /// **'Что увидят друзья'**
  String get mySongsPreviewTitle;

  /// No description provided for @mySongsPreviewBody.
  ///
  /// In ru, this message translates to:
  /// **'Если в игре выпадет твоя песня, все увидят её название, исполнителя и что она твоя. Весь список целиком не увидит никто.'**
  String get mySongsPreviewBody;

  /// No description provided for @lobbyAddMySongs.
  ///
  /// In ru, this message translates to:
  /// **'Добавить мои песни'**
  String get lobbyAddMySongs;

  /// No description provided for @lobbyUpdateMySongs.
  ///
  /// In ru, this message translates to:
  /// **'Обновить мои песни'**
  String get lobbyUpdateMySongs;

  /// No description provided for @lobbyOpenMySongs.
  ///
  /// In ru, this message translates to:
  /// **'Открыть «Мои песни»'**
  String get lobbyOpenMySongs;

  /// Consent line before PUT /v1/rooms/{room_id}/pool.
  ///
  /// In ru, this message translates to:
  /// **'Эти песни будут показаны комнате как твои'**
  String get lobbyPoolConsentBody;

  /// No description provided for @lobbyPoolConsentConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get lobbyPoolConsentConfirm;

  /// No description provided for @lobbyPoolSent.
  ///
  /// In ru, this message translates to:
  /// **'Твои песни в игре'**
  String get lobbyPoolSent;

  /// No description provided for @lobbyPoolFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось добавить песни'**
  String get lobbyPoolFailed;

  /// No description provided for @lobbyPoolNeedPicks.
  ///
  /// In ru, this message translates to:
  /// **'Сначала выбери хотя бы {min} песен в «Мои песни»'**
  String lobbyPoolNeedPicks(int min);

  /// No description provided for @lobbyPoolTrackCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} песня} few{{count} песни} many{{count} песен} other{{count} песни}}'**
  String lobbyPoolTrackCount(int count);

  /// No description provided for @lobbyPoolTooSmall.
  ///
  /// In ru, this message translates to:
  /// **'У {name} меньше {min} песен'**
  String lobbyPoolTooSmall(String name, int min);

  /// No description provided for @lobbyNeedAnyPool.
  ///
  /// In ru, this message translates to:
  /// **'Хотя бы одному игроку нужно добавить свои песни'**
  String get lobbyNeedAnyPool;

  /// Lobby hint for the host of an external_player (BYOP) room.
  ///
  /// In ru, this message translates to:
  /// **'Ты диджей: включай песни в своём музыкальном приложении, на колонке погромче'**
  String get lobbyDjHint;

  /// «Мои песни» still holds legacy catalogue picks (test_catalog); they cannot be saved as songs.
  ///
  /// In ru, this message translates to:
  /// **'Песни из старого каталога нужно заменить новыми'**
  String get mySongsLegacyHint;

  /// emoji_quiz game mode; since wave 4 the UI calls it «Угадай песню» (owner decision) [новое имя — согласовать].
  ///
  /// In ru, this message translates to:
  /// **'Угадай песню'**
  String get modeEmojiQuiz;

  /// No description provided for @modeEmojiQuizHint.
  ///
  /// In ru, this message translates to:
  /// **'Угадай песню по эмодзи — музыка не нужна'**
  String get modeEmojiQuizHint;

  /// Question of an emoji round.
  ///
  /// In ru, this message translates to:
  /// **'Какая это песня?'**
  String get gamePromptEmoji;

  /// Screen reader label of the emoji line before the round opens.
  ///
  /// In ru, this message translates to:
  /// **'Эмодзи появятся на старте'**
  String get gameEmojiHidden;

  /// No description provided for @gameEmojiSemantics.
  ///
  /// In ru, this message translates to:
  /// **'Эмодзи: {emoji}'**
  String gameEmojiSemantics(String emoji);

  /// Release year in the reveal (a string, so it is not grouped as a number).
  ///
  /// In ru, this message translates to:
  /// **'Год: {year}'**
  String revealYear(String year);

  /// Guests of a BYOP round wait for the round DJ.
  ///
  /// In ru, this message translates to:
  /// **'{name} включает песню…'**
  String gameDjStartingNamed(String name);

  /// The round's DJ may not answer (dj_ineligible).
  ///
  /// In ru, this message translates to:
  /// **'Ты DJ этого раунда — отвечают остальные'**
  String get gameDjRoundNoAnswer;

  /// Stays over the spare round for void_notice_ms.
  ///
  /// In ru, this message translates to:
  /// **'Раунд пропущен: {reason}'**
  String gameVoidedNotice(String reason);

  /// No description provided for @gameVoidedNoticeNoReason.
  ///
  /// In ru, this message translates to:
  /// **'Раунд пропущен'**
  String get gameVoidedNoticeNoReason;

  /// lobby.set_can_dj toggle (BYOP DJ rotation).
  ///
  /// In ru, this message translates to:
  /// **'Могу включать музыку'**
  String get lobbyCanDj;

  /// No description provided for @lobbyCanDjHint.
  ///
  /// In ru, this message translates to:
  /// **'Иногда DJ будешь ты: включишь песню в своём музыкальном приложении'**
  String get lobbyCanDjHint;

  /// A player who opted in to the DJ role.
  ///
  /// In ru, this message translates to:
  /// **'DJ'**
  String get lobbyDjBadge;

  /// emoji_quiz catalogue markets.
  ///
  /// In ru, this message translates to:
  /// **'Какие песни'**
  String get lobbyEmojiMarkets;

  /// No description provided for @lobbyEmojiMarketIntl.
  ///
  /// In ru, this message translates to:
  /// **'Международные'**
  String get lobbyEmojiMarketIntl;

  /// No description provided for @lobbyEmojiMarketPl.
  ///
  /// In ru, this message translates to:
  /// **'Польские'**
  String get lobbyEmojiMarketPl;

  /// emoji_quiz opt-in market cis (owner decision 2026-09-30: the UI name is «СНГ»). Off by default.
  ///
  /// In ru, this message translates to:
  /// **'СНГ'**
  String get lobbyEmojiMarketCis;

  /// emoji_quiz lobby emoji_retro: also play songs released before the server's emoji_min_year. Off by default.
  ///
  /// In ru, this message translates to:
  /// **'Ретро (до {year})'**
  String lobbyEmojiRetro(String year);

  /// emoji_quiz emoji_max_difficulty.
  ///
  /// In ru, this message translates to:
  /// **'Сложность'**
  String get lobbyEmojiDifficulty;

  /// No description provided for @lobbyEmojiDifficultyEasy.
  ///
  /// In ru, this message translates to:
  /// **'Лёгкие'**
  String get lobbyEmojiDifficultyEasy;

  /// No description provided for @lobbyEmojiDifficultyMedium.
  ///
  /// In ru, this message translates to:
  /// **'До средних'**
  String get lobbyEmojiDifficultyMedium;

  /// No description provided for @lobbyEmojiDifficultyHard.
  ///
  /// In ru, this message translates to:
  /// **'Все, включая сложные'**
  String get lobbyEmojiDifficultyHard;

  /// No description provided for @lobbyEmojiHint.
  ///
  /// In ru, this message translates to:
  /// **'Без музыки: хватит телефонов'**
  String get lobbyEmojiHint;

  /// youtube_embed DJ: they start the video in the official player themself (no autoplay). {playIcon} is a play icon drawn inline (never an emoji); screen readers get gameYouTubePlayButton in its place.
  ///
  /// In ru, this message translates to:
  /// **'Нажми {playIcon} в плеере. Если YouTube сначала покажет рекламу, дождись песни'**
  String gameYouTubePressPlay(String playIcon);

  /// Screen-reader stand-in for the play icon in gameYouTubePressPlay (accusative in ru) [новое имя — согласовать].
  ///
  /// In ru, this message translates to:
  /// **'кнопку воспроизведения'**
  String get gameYouTubePlayButton;

  /// Consent sheet before the embedded YouTube player loads (EU/EEA, YouTube policy III.E.4.i) [новое имя — согласовать].
  ///
  /// In ru, this message translates to:
  /// **'Включить плеер YouTube?'**
  String get gameYouTubeConsentTitle;

  /// No description provided for @gameYouTubeConsentBody.
  ///
  /// In ru, this message translates to:
  /// **'Песня сыграет в официальном плеере YouTube. Когда он загружается, YouTube (Google) получает данные о твоём устройстве и может показать рекламу.'**
  String get gameYouTubeConsentBody;

  /// No description provided for @gameYouTubeConsentAllow.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить'**
  String get gameYouTubeConsentAllow;

  /// No description provided for @gameYouTubeConsentDecline.
  ///
  /// In ru, this message translates to:
  /// **'Нет, включу вручную'**
  String get gameYouTubeConsentDecline;

  /// youtube_embed DJ fell back to the BYOP cue (every video failed).
  ///
  /// In ru, this message translates to:
  /// **'Видео не играет — включи песню вручную'**
  String get gameYouTubeFallback;

  /// youtube_embed DJ: the window (split screen, a small window) cannot hold a legal player right now, so the DJ gets the cue until it grows [новое имя — согласовать].
  ///
  /// In ru, this message translates to:
  /// **'Окно слишком маленькое для плеера YouTube. Разверни его или включи песню вручную'**
  String get gameYouTubeWindowTooSmall;

  /// youtube_embed DJ declined the player consent.
  ///
  /// In ru, this message translates to:
  /// **'Без YouTube: включи песню в своём приложении'**
  String get gameYouTubeDeclined;

  /// «Мои песни»: link a YouTube video to a song pick (wave 4) [новое имя — согласовать].
  ///
  /// In ru, this message translates to:
  /// **'Видео YouTube'**
  String get mySongsYouTubeAdd;

  /// No description provided for @mySongsYouTubeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Видео для песни «{song}»'**
  String mySongsYouTubeTitle(String song);

  /// No description provided for @mySongsYouTubeHint.
  ///
  /// In ru, this message translates to:
  /// **'Вставь ссылку на официальное видео песни — когда ты DJ, она сыграет в плеере YouTube'**
  String get mySongsYouTubeHint;

  /// No description provided for @mySongsYouTubeField.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка на YouTube'**
  String get mySongsYouTubeField;

  /// No description provided for @mySongsYouTubePaste.
  ///
  /// In ru, this message translates to:
  /// **'Вставить'**
  String get mySongsYouTubePaste;

  /// No description provided for @mySongsYouTubeCheck.
  ///
  /// In ru, this message translates to:
  /// **'Проверить'**
  String get mySongsYouTubeCheck;

  /// No description provided for @mySongsYouTubeUse.
  ///
  /// In ru, this message translates to:
  /// **'Привязать'**
  String get mySongsYouTubeUse;

  /// No description provided for @mySongsYouTubeCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get mySongsYouTubeCancel;

  /// No description provided for @mySongsYouTubeRemove.
  ///
  /// In ru, this message translates to:
  /// **'Убрать видео'**
  String get mySongsYouTubeRemove;

  /// No description provided for @mySongsYouTubeInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Это не ссылка на видео YouTube'**
  String get mySongsYouTubeInvalid;

  /// No description provided for @mySongsYouTubeNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Видео не найдено или скрыто'**
  String get mySongsYouTubeNotFound;

  /// No description provided for @mySongsYouTubeNotEmbeddable.
  ///
  /// In ru, this message translates to:
  /// **'Автор запретил показывать это видео в приложениях'**
  String get mySongsYouTubeNotEmbeddable;

  /// No description provided for @mySongsYouTubeFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось проверить ссылку'**
  String get mySongsYouTubeFailed;

  /// No description provided for @mySongsYouTubeLinked.
  ///
  /// In ru, this message translates to:
  /// **'Видео YouTube привязано'**
  String get mySongsYouTubeLinked;

  /// No description provided for @mySongsYouTubeChannel.
  ///
  /// In ru, this message translates to:
  /// **'Канал: {channel}'**
  String mySongsYouTubeChannel(String channel);

  /// Shape marker of answer slot A (screen readers: '{marker}: {option}').
  ///
  /// In ru, this message translates to:
  /// **'Круг'**
  String get gameMarkerCircle;

  /// No description provided for @gameMarkerTriangle.
  ///
  /// In ru, this message translates to:
  /// **'Треугольник'**
  String get gameMarkerTriangle;

  /// No description provided for @gameMarkerSquare.
  ///
  /// In ru, this message translates to:
  /// **'Квадрат'**
  String get gameMarkerSquare;

  /// No description provided for @gameMarkerDiamond.
  ///
  /// In ru, this message translates to:
  /// **'Ромб'**
  String get gameMarkerDiamond;

  /// No description provided for @gameMarkerHexagon.
  ///
  /// In ru, this message translates to:
  /// **'Шестиугольник'**
  String get gameMarkerHexagon;

  /// No description provided for @gameMarkerStar.
  ///
  /// In ru, this message translates to:
  /// **'Звезда'**
  String get gameMarkerStar;

  /// Screen reader label of an answer tile: its shape marker and the option text.
  ///
  /// In ru, this message translates to:
  /// **'{marker}: {option}'**
  String gameAnswerSemantics(String marker, String option);

  /// Under the answer tile the player picked.
  ///
  /// In ru, this message translates to:
  /// **'Твой ответ'**
  String get gameYourPick;

  /// Reveal: the correct answer tile and the result pill.
  ///
  /// In ru, this message translates to:
  /// **'Верно'**
  String get gameTileCorrect;

  /// Screen reader value of the answer timer ring (visual only; the server decides time-up).
  ///
  /// In ru, this message translates to:
  /// **'Осталось {seconds} с'**
  String gameTimeLeftSemantics(int seconds);

  /// Streak chip on the reveal (RoundResult.streak from the server, shown from 2).
  ///
  /// In ru, this message translates to:
  /// **'Серия ×{count}'**
  String revealStreak(int count);

  /// Tooltip of the host badge on a player avatar.
  ///
  /// In ru, this message translates to:
  /// **'Ведущий'**
  String get playerBadgeHost;

  /// Tooltip of the DJ badge on a player avatar.
  ///
  /// In ru, this message translates to:
  /// **'DJ'**
  String get playerBadgeDj;

  /// Tooltip of the ready badge on a player avatar.
  ///
  /// In ru, this message translates to:
  /// **'На старте'**
  String get playerBadgeReady;

  /// The DJ's «Музыка играет!» after the tap: a tonal done state under the YouTube player (never a SnackBar).
  ///
  /// In ru, this message translates to:
  /// **'Отмечено'**
  String get gameDjTapped;

  /// Second step of «Выйти» on the DJ screen with the YouTube player: an inline confirm in the app bar (no dialog over the player).
  ///
  /// In ru, this message translates to:
  /// **'Выйти из игры?'**
  String get gameLeaveInlineConfirm;

  /// Cancels the inline leave confirm on the DJ player screen.
  ///
  /// In ru, this message translates to:
  /// **'Остаться'**
  String get gameLeaveInlineCancel;

  /// Tooltip of the copy button next to the room code in the lobby.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать код'**
  String get lobbyCopyCode;

  /// Toast after the room code was copied.
  ///
  /// In ru, this message translates to:
  /// **'Код скопирован'**
  String get lobbyCodeCopied;

  /// Screen reader label of the onboarding step pills.
  ///
  /// In ru, this message translates to:
  /// **'Шаг {step} из {total}'**
  String onboardingStepSemantics(int step, int total);

  /// Screen reader label of the rank-up arrow in the standings.
  ///
  /// In ru, this message translates to:
  /// **'вверх на {n}'**
  String standingsMovedUp(int n);

  /// Screen reader label of the rank-down arrow in the standings.
  ///
  /// In ru, this message translates to:
  /// **'вниз на {n}'**
  String standingsMovedDown(int n);

  /// Screen reader label of a podium column; points is the formatted pointsShort text.
  ///
  /// In ru, this message translates to:
  /// **'{rank} место: {name}, {points}'**
  String resultsPodiumSemantics(int rank, String name, String points);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pl', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pl':
      return AppLocalizationsPl();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
