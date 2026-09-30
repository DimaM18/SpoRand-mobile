// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Muzyczna impreza';

  @override
  String get bootLabelConfig => 'Wczytujemy ustawienia…';

  @override
  String get bootLabelWarmup => 'Przygotowujemy dźwięki…';

  @override
  String get bootLabelSdk => 'Łączymy usługi…';

  @override
  String get bootLabelEnter => 'Jazda!';

  @override
  String bootProgressSemantics(int percent) {
    return 'Ładowanie: $percent%';
  }

  @override
  String get bootFailedTitle => 'Nie udało się uruchomić';

  @override
  String get bootFailedBody =>
      'Sprawdź połączenie z internetem i spróbuj ponownie.';

  @override
  String get bootRetry => 'Spróbuj ponownie';

  @override
  String get forceUpdateTitle => 'Czas na aktualizację';

  @override
  String get forceUpdateBody =>
      'Ta wersja nie jest już obsługiwana. Zaktualizuj aplikację, aby dalej grać.';

  @override
  String get forceUpdateAction => 'Aktualizuj';

  @override
  String get maintenanceTitle => 'Krótka przerwa';

  @override
  String get maintenanceBody =>
      'Stroimy serwery. Wrócimy wkrótce — zajrzyj za kilka minut.';

  @override
  String get maintenanceRetry => 'Sprawdź ponownie';

  @override
  String get onboardingAgeTitle => 'Rok urodzenia';

  @override
  String get onboardingAgeSubtitle =>
      'Dzięki temu dopasujemy aplikację do Twojego wieku.';

  @override
  String get onboardingAgeFieldLabel => 'Rok';

  @override
  String get onboardingAgeFieldHint => 'RRRR';

  @override
  String get onboardingAgeInvalid => 'Wpisz rok w formacie czterocyfrowym';

  @override
  String get onboardingContinue => 'Dalej';

  @override
  String get onboardingBlockedTitle => 'Jeszcze nie teraz';

  @override
  String get onboardingBlockedBody =>
      'Ta aplikacja jest przeznaczona dla graczy w wieku od 13 lat.';

  @override
  String get onboardingConsentTitle => 'Twoja prywatność';

  @override
  String get onboardingConsentBody =>
      'Nigdy nie przekazujemy Twojej muzyki do analityki ani reklam. Możesz pomóc nam ulepszać grę anonimowymi statystykami — to opcjonalne i możesz to zmienić w ustawieniach.';

  @override
  String get onboardingConsentAnalytics => 'Wysyłaj anonimowe statystyki';

  @override
  String get onboardingConsentMinorNote =>
      'Dla graczy poniżej 16 lat statystyki są wyłączone.';

  @override
  String get onboardingConsentStart => 'Zaczynamy';

  @override
  String get homeHeadline => 'Czyja to piosenka?';

  @override
  String get homeSubtitle =>
      'Imprezowa gra dla znajomych: posłuchaj fragmentu i zgadnij szybciej niż inni.';

  @override
  String get homeCreateRoom => 'Utwórz pokój';

  @override
  String get homeJoinTitle => 'Masz kod pokoju?';

  @override
  String get homeJoinCodeLabel => 'Kod z 6 znaków';

  @override
  String get homeJoinAction => 'Dołącz';

  @override
  String get homeJoinCodeInvalid => 'Kod składa się z 6 liter i cyfr';

  @override
  String get homeRemoveAds => 'Graj bez reklam';

  @override
  String get homeSettingsTooltip => 'Ustawienia';

  @override
  String get settingsTitle => 'Ustawienia';

  @override
  String get settingsPrivacySection => 'Prywatność';

  @override
  String get settingsAnalyticsTitle => 'Anonimowe statystyki';

  @override
  String get settingsAnalyticsSubtitle =>
      'Pomagają znajdować błędy i ulepszać grę';

  @override
  String get settingsAnalyticsUnavailable =>
      'Niedostępne dla graczy poniżej 16 lat';

  @override
  String get settingsPrivacyOptions => 'Reklamy i zgody';

  @override
  String get settingsPurchasesSection => 'Zakupy';

  @override
  String get settingsRemoveAds => 'Usuń reklamy';

  @override
  String get settingsRestorePurchases => 'Przywróć zakupy';

  @override
  String get settingsRestoreDone => 'Zakupy zostały przywrócone';

  @override
  String get settingsRestoreNothing => 'Nie znaleziono zakupów';

  @override
  String get settingsRestoreFailed => 'Nie udało się przywrócić zakupów';

  @override
  String get settingsAboutSection => 'O aplikacji';

  @override
  String settingsVersion(String version) {
    return 'Wersja $version';
  }

  @override
  String settingsDegraded(String steps) {
    return 'Tryb ograniczony: $steps';
  }

  @override
  String get settingsTerms => 'Warunki korzystania';

  @override
  String get settingsPrivacyPolicy => 'Polityka prywatności';

  @override
  String get paywallTitle => 'Graj bez ograniczeń';

  @override
  String get paywallSubtitle => 'Więcej rund, więcej znajomych, zero reklam.';

  @override
  String get paywallPerkNoAds => 'Bez reklam po grze';

  @override
  String get paywallPerkRounds => 'Do 50 rund w grze';

  @override
  String get paywallPerkPlayers => 'Do 12 graczy w pokoju';

  @override
  String get paywallRemoveAds => 'Bez reklam';

  @override
  String paywallRemoveAdsDetail(String price) {
    return 'Jednorazowy zakup — $price';
  }

  @override
  String get paywallPremiumMonthly => 'Premium miesięcznie';

  @override
  String get paywallPremiumYearly => 'Premium rocznie';

  @override
  String paywallPerMonth(String price) {
    return '$price miesięcznie';
  }

  @override
  String paywallPerYear(String price) {
    return '$price rocznie';
  }

  @override
  String paywallTrial(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dnia za darmo',
      many: '$days dni za darmo',
      few: '$days dni za darmo',
      one: '$days dzień za darmo',
    );
    return '$_temp0';
  }

  @override
  String get paywallBuy => 'Kontynuuj';

  @override
  String get paywallRestore => 'Przywróć zakupy';

  @override
  String get paywallLegal =>
      'Subskrypcja odnawia się automatycznie, jeśli nie anulujesz jej w ustawieniach sklepu co najmniej 24 godziny przed końcem okresu. Płatność jest pobierana z konta sklepu.';

  @override
  String get paywallUnavailable => 'Zakupy są teraz niedostępne';

  @override
  String get paywallLoadFailed => 'Nie udało się wczytać ofert';

  @override
  String get paywallRetry => 'Ponów';

  @override
  String get paywallPurchased => 'Gotowe! Dzięki za wsparcie';

  @override
  String get paywallPending => 'Zakup czeka na zatwierdzenie';

  @override
  String get paywallFailed => 'Zakup się nie powiódł';

  @override
  String get paywallOwned => 'Już kupione';

  @override
  String get placeholderBody => 'Ten ekran pojawi się w następnej wersji.';

  @override
  String joinTitle(String code) {
    return 'Pokój $code';
  }

  @override
  String get notFoundTitle => 'Nie znaleziono strony';

  @override
  String get notFoundAction => 'Strona główna';

  @override
  String get createRoomTitle => 'Nowy pokój';

  @override
  String get createRoomModeLabel => 'Tryb gry';

  @override
  String get modeWhoseSong => 'Czyja to piosenka?';

  @override
  String get modeWhoseSongHint => 'Zgadnij, z czyjej muzyki jest fragment';

  @override
  String get modeGuessTrack => 'Zgadnij utwór';

  @override
  String get modeGuessTrackHint => 'Cztery odpowiedzi: nazwij piosenkę';

  @override
  String get displayNameLabel => 'Twoje imię w grze';

  @override
  String get displayNameInvalid => 'Od 2 do 20 znaków';

  @override
  String get createRoomAction => 'Utwórz pokój';

  @override
  String get joinSubtitle => 'Jak mamy cię nazywać?';

  @override
  String get joinAction => 'Dołącz do pokoju';

  @override
  String get roomErrorNotFound => 'Nie znaleziono pokoju. Sprawdź kod';

  @override
  String get roomErrorFull => 'Pokój jest pełny';

  @override
  String get roomErrorLocked => 'Gra już trwa. Poczekaj na wyniki';

  @override
  String get roomErrorRateLimited => 'Zbyt wiele prób. Odczekaj minutę';

  @override
  String get roomErrorNetwork => 'Brak połączenia z serwerem';

  @override
  String get roomErrorOther => 'Coś poszło nie tak. Spróbuj ponownie';

  @override
  String get lobbyTitle => 'Poczekalnia';

  @override
  String get lobbyCodeLabel => 'Kod pokoju';

  @override
  String get lobbyShare => 'Zaproś';

  @override
  String get lobbyCopyLink => 'Kopiuj link';

  @override
  String get lobbyLinkCopied => 'Link skopiowany';

  @override
  String lobbyShareText(String code, String link) {
    return 'Dołącz do gry! Kod pokoju: $code\n$link';
  }

  @override
  String lobbyShareTextNoLink(String code) {
    return 'Dołącz do gry! Kod pokoju: $code';
  }

  @override
  String lobbyQrSemantics(String code) {
    return 'Kod QR do pokoju $code';
  }

  @override
  String lobbyPlayersTitle(int count) {
    return 'Gracze: $count';
  }

  @override
  String get lobbyHostBadge => 'Gospodarz';

  @override
  String get lobbyYouBadge => 'Ty';

  @override
  String get lobbyReady => 'Gotowy';

  @override
  String get lobbyNotReady => 'Niegotowy';

  @override
  String get lobbyAway => 'Łączy się ponownie';

  @override
  String get lobbyConnecting => 'Łączenie z pokojem…';

  @override
  String get lobbyReconnecting => 'Utracono połączenie. Łączenie ponownie…';

  @override
  String get lobbySettingsTitle => 'Ustawienia gry';

  @override
  String get lobbyRoundsLabel => 'Rundy';

  @override
  String lobbyRoundsLocked(int count) {
    return '$count rund w Premium';
  }

  @override
  String get lobbyStart => 'Zacznij grę';

  @override
  String lobbyNeedPlayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Potrzeba co najmniej $count graczy',
      many: 'Potrzeba co najmniej $count graczy',
      few: 'Potrzeba co najmniej $count graczy',
      one: 'Potrzebny co najmniej $count gracz',
    );
    return '$_temp0';
  }

  @override
  String lobbyNeedContributors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Jeszcze $count graczy musi dodać piosenki',
      many: 'Jeszcze $count graczy musi dodać piosenki',
      few: 'Jeszcze $count graczy musi dodać piosenki',
      one: 'Jeszcze $count gracz musi dodać piosenki',
    );
    return '$_temp0';
  }

  @override
  String get lobbyWaitingForHost => 'Gospodarz zaraz zacznie grę';

  @override
  String get lobbyImReady => 'Jestem gotowy';

  @override
  String get lobbyKick => 'Usuń z pokoju';

  @override
  String get lobbyReport => 'Zgłoś';

  @override
  String get lobbyReportTitle => 'Powód zgłoszenia';

  @override
  String get reportReasonName => 'Obraźliwa nazwa';

  @override
  String get reportReasonCheating => 'Oszukuje';

  @override
  String get reportReasonHarassment => 'Nękanie lub obrażanie';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonOther => 'Inne';

  @override
  String get lobbyReportSent => 'Zgłoszenie wysłane. Dziękujemy!';

  @override
  String get lobbyReportFailed => 'Nie udało się wysłać zgłoszenia';

  @override
  String get lobbyLeave => 'Wyjdź';

  @override
  String get lobbyLeaveConfirmTitle => 'Opuścić pokój?';

  @override
  String get lobbyLeaveConfirmBody =>
      'Możesz wrócić z tym samym kodem, dopóki gra się nie zacznie.';

  @override
  String get commonCancel => 'Anuluj';

  @override
  String get lobbyNoRoom => 'Nie jesteś w pokoju';

  @override
  String get lobbyBackHome => 'Na stronę główną';

  @override
  String get roomEndedKicked => 'Gospodarz usunął cię z pokoju';

  @override
  String get roomEndedClosed => 'Pokój został zamknięty';

  @override
  String get roomEndedReplaced => 'Otworzyłeś ten pokój na innym urządzeniu';

  @override
  String get roomEndedVersion => 'Zaktualizuj aplikację, aby grać';

  @override
  String get roomEndedLost => 'Nie udało się ponownie połączyć z pokojem';

  @override
  String get errorNotHost => 'Tylko gospodarz może to zrobić';

  @override
  String get errorPoolInsufficient => 'Graczom brakuje piosenek';

  @override
  String get errorTierRequired => 'To ustawienie wymaga Premium';

  @override
  String get errorPlaybackUnavailable =>
      'Telefon gospodarza nie może odtworzyć muzyki';

  @override
  String get errorInvalidState => 'Nie można tego teraz zrobić';

  @override
  String get errorRateLimited => 'Za szybko. Poczekaj chwilę';

  @override
  String get errorGeneric => 'Coś poszło nie tak';

  @override
  String get gameWaiting => 'Czekamy na start gry…';

  @override
  String get gameStartingTitle => 'Przygotuj się!';

  @override
  String gameStartingRounds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rundy',
      many: '$count rund',
      few: '$count rundy',
      one: '$count runda',
    );
    return '$_temp0';
  }

  @override
  String gameRoundOf(int current, int total) {
    return 'Runda $current z $total';
  }

  @override
  String get gameBonusRound => 'Runda bonusowa';

  @override
  String get gamePromptWhoseSong => 'Czyja to piosenka?';

  @override
  String get gamePromptGuessTrack => 'Co to za utwór?';

  @override
  String get gameListen => 'Słuchaj…';

  @override
  String get gameTapFast => 'Stuknij najszybciej!';

  @override
  String get gameYourTrack => 'To twój utwór!';

  @override
  String get gameYourTrackHint => 'Zobacz, kto zgadnie';

  @override
  String get gameAnswerSent => 'Odpowiedź wysłana';

  @override
  String get gameAnswerAccepted => 'Odpowiedź przyjęta!';

  @override
  String get gameAnswerRejected => 'Odpowiedź nie została zaliczona';

  @override
  String get gameTimeUp => 'Czas minął';

  @override
  String gameProgress(int answered, int eligible) {
    return 'Odpowiedziało $answered z $eligible';
  }

  @override
  String get gameAirplayWarning =>
      'AirPlay opóźnia dźwięk o około 2 sekundy. Lepiej użyć głośnika telefonu.';

  @override
  String revealCorrect(int points) {
    return 'Dobrze! +$points';
  }

  @override
  String get revealWrong => 'Pudło';

  @override
  String get revealNoAnswer => 'Brak odpowiedzi';

  @override
  String get revealOwnerYou => 'To był twój utwór';

  @override
  String revealReaction(String seconds) {
    return 'Reakcja: $seconds s';
  }

  @override
  String revealOwner(String names) {
    return 'To utwór: $names';
  }

  @override
  String revealAnswer(String label) {
    return 'Odpowiedź: $label';
  }

  @override
  String get revealStandings => 'Tabela';

  @override
  String revealGained(int points) {
    return '+$points';
  }

  @override
  String pointsShort(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points pkt',
      many: '$points pkt',
      few: '$points pkt',
      one: '$points pkt',
    );
    return '$_temp0';
  }

  @override
  String get gameVoided => 'Runda anulowana: gramy zapasową';

  @override
  String get gameVoidedPlayback => 'Nie udało się włączyć muzyki';

  @override
  String get gameVoidedHost => 'Gospodarz się rozłączył';

  @override
  String get gameVoidedServer => 'Serwer został zrestartowany';

  @override
  String get gamePaused => 'Czekamy na gospodarza…';

  @override
  String get gamePausedHint => 'Gra będzie kontynuowana, gdy wróci';

  @override
  String get bonusOfferTitle => 'Obejrzyj reklamę: +1 runda dla wszystkich';

  @override
  String get bonusOfferAction => 'Oglądaj';

  @override
  String get bonusOfferWaiting => 'Runda bonusowa? Ktoś może obejrzeć reklamę';

  @override
  String bonusSponsorWatching(String name) {
    return '$name ogląda reklamę…';
  }

  @override
  String get bonusYouWatching => 'Przygotowujemy reklamę…';

  @override
  String get bonusVerifying => 'Sprawdzamy nagrodę…';

  @override
  String bonusGranted(String name) {
    return '+1 runda dla wszystkich! Dzięki, $name';
  }

  @override
  String get bonusCancelled => 'Tym razem bez rundy bonusowej';

  @override
  String get bonusCancelledSsv =>
      'Nie udało się potwierdzić obejrzenia. Przepraszamy!';

  @override
  String get adBreakCounting => 'Liczymy punkty…';

  @override
  String get upsellTitle => 'Graj bez reklam';

  @override
  String upsellPrice(String price) {
    return 'Graj bez reklam: $price';
  }

  @override
  String get upsellAction => 'Więcej';

  @override
  String get resultsTitle => 'Wyniki';

  @override
  String get resultsPlayAgain => 'Zagraj jeszcze raz';

  @override
  String get resultsWaitingHost => 'Gospodarz może zacząć nową grę';

  @override
  String resultsRounds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rozegrano $count rundy',
      many: 'Rozegrano $count rund',
      few: 'Rozegrano $count rundy',
      one: 'Rozegrano $count rundę',
    );
    return '$_temp0';
  }

  @override
  String get resultsBonusUsed => 'Z rundą bonusową';

  @override
  String resultsCorrect(int count) {
    return 'Trafione: $count';
  }

  @override
  String get debugClockTitle => 'Kalibracja zegara';

  @override
  String get debugClockHint =>
      'Stuknij obszar kilka razy. Test sprawdza, czy czasy dotyku i klatek są na zegarze urządzenia.';

  @override
  String get debugClockTapArea => 'Stuknij tutaj';

  @override
  String debugClockPassed(int count) {
    return 'Zegary zgodne ($count pomiarów)';
  }

  @override
  String debugClockFailed(int count) {
    return 'Zegary NIE są zgodne ($count pomiarów)';
  }

  @override
  String get debugClockCopy => 'Kopiuj raport';

  @override
  String get debugClockClear => 'Wyczyść';

  @override
  String get settingsClockCalibration => 'Kalibracja zegara (dla programistów)';

  @override
  String get gameDjStarting => 'Prowadzący włącza piosenkę…';

  @override
  String get gameDjCueTitle => 'Włącz tę piosenkę w swojej aplikacji muzycznej';

  @override
  String get gameDjCueSecret => 'Tytuł widzisz tylko ty — nie pokazuj ekranu';

  @override
  String get gameDjOpenApp => 'Otwórz w aplikacji muzycznej';

  @override
  String get gameDjOpenAppFailed =>
      'Nie udało się otworzyć aplikacji — znajdź piosenkę ręcznie';

  @override
  String get gameDjMusicPlaying => 'Muzyka gra!';

  @override
  String get gameDjMusicPlayingHint => 'Stuknij, gdy tylko piosenka zabrzmi';

  @override
  String get gameDjWatchingTitle => 'Jesteś DJ-em!';

  @override
  String get gameDjWatchingHint => 'W tej rundzie odpowiadają goście';

  @override
  String get gameAnswerRejectedDj => 'DJ nie odpowiada w tej rundzie';

  @override
  String get gameTextRoundHint => 'Runda bez muzyki: czytaj i zgaduj';

  @override
  String get gameTextRoundLocked => 'Przygotujcie się…';

  @override
  String get homeMySongs => 'Moje piosenki';

  @override
  String get mySongsTitle => 'Moje piosenki';

  @override
  String get mySongsSearchLabel => 'Piosenka lub wykonawca';

  @override
  String get mySongsSearchEmpty => 'Nic nie znaleziono';

  @override
  String get mySongsSearchFailed =>
      'Wyszukiwanie nie powiodło się. Sprawdź internet.';

  @override
  String mySongsSelected(int count, int max) {
    return 'Wybrano $count z $max';
  }

  @override
  String mySongsNeedMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dodaj jeszcze $count piosenki',
      many: 'Dodaj jeszcze $count piosenek',
      few: 'Dodaj jeszcze $count piosenki',
      one: 'Dodaj jeszcze $count piosenkę',
    );
    return '$_temp0';
  }

  @override
  String mySongsFull(int max) {
    return 'Możesz wybrać najwyżej $max piosenek';
  }

  @override
  String get mySongsSave => 'Zapisz';

  @override
  String get mySongsSaved => 'Piosenki zapisane';

  @override
  String get mySongsSaveFailed => 'Nie udało się zapisać';

  @override
  String get mySongsLoadFailed => 'Nie udało się wczytać twoich piosenek';

  @override
  String mySongsEmpty(int min, int max) {
    return 'Znajdź od $min do $max ulubionych piosenek — znajomi będą zgadywać, czyje są';
  }

  @override
  String get mySongsAdd => 'Dodaj';

  @override
  String get mySongsRemove => 'Usuń';

  @override
  String get mySongsPreviewTitle => 'Co zobaczą znajomi';

  @override
  String get mySongsPreviewBody =>
      'Jeśli w grze wypadnie twoja piosenka, wszyscy zobaczą jej tytuł, wykonawcę i to, że jest twoja. Całej listy nie zobaczy nikt.';

  @override
  String get lobbyAddMySongs => 'Dodaj moje piosenki';

  @override
  String get lobbyUpdateMySongs => 'Zaktualizuj moje piosenki';

  @override
  String get lobbyOpenMySongs => 'Otwórz Moje piosenki';

  @override
  String get lobbyPoolConsentBody =>
      'Te piosenki zostaną pokazane w pokoju jako twoje';

  @override
  String get lobbyPoolConsentConfirm => 'Potwierdź';

  @override
  String get lobbyPoolSent => 'Twoje piosenki są w grze';

  @override
  String get lobbyPoolFailed => 'Nie udało się dodać piosenek';

  @override
  String lobbyPoolNeedPicks(int min) {
    return 'Najpierw wybierz co najmniej $min piosenek w Moich piosenkach';
  }

  @override
  String lobbyPoolTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count piosenki',
      many: '$count piosenek',
      few: '$count piosenki',
      one: '$count piosenka',
    );
    return '$_temp0';
  }

  @override
  String lobbyPoolTooSmall(String name, int min) {
    return '$name ma mniej niż $min piosenek';
  }

  @override
  String get lobbyNeedAnyPool => 'Przynajmniej jeden gracz musi dodać piosenki';

  @override
  String get lobbyDjHint =>
      'Jesteś DJ-em: włączaj piosenki w swojej aplikacji muzycznej, głośno na głośniku';

  @override
  String get mySongsLegacyHint =>
      'Piosenki ze starego katalogu trzeba zastąpić nowymi';

  @override
  String get modeEmojiQuiz => 'Zgadnij piosenkę';

  @override
  String get modeEmojiQuizHint =>
      'Zgadnijcie piosenkę z emoji — muzyka niepotrzebna';

  @override
  String get gamePromptEmoji => 'Jaka to piosenka?';

  @override
  String get gameEmojiHidden => 'Emoji pojawią się na starcie';

  @override
  String gameEmojiSemantics(String emoji) {
    return 'Emoji: $emoji';
  }

  @override
  String revealYear(String year) {
    return 'Rok: $year';
  }

  @override
  String gameDjStartingNamed(String name) {
    return '$name włącza piosenkę…';
  }

  @override
  String get gameDjRoundNoAnswer =>
      'Jesteś DJ-em tej rundy — odpowiadają pozostali';

  @override
  String gameVoidedNotice(String reason) {
    return 'Runda pominięta: $reason';
  }

  @override
  String get gameVoidedNoticeNoReason => 'Runda pominięta';

  @override
  String get lobbyCanDj => 'Mogę włączać muzykę';

  @override
  String get lobbyCanDjHint =>
      'Czasem to ty będziesz DJ-em: włączysz piosenkę w swojej aplikacji muzycznej';

  @override
  String get lobbyDjBadge => 'DJ';

  @override
  String get lobbyEmojiMarkets => 'Piosenki';

  @override
  String get lobbyEmojiMarketIntl => 'Międzynarodowe';

  @override
  String get lobbyEmojiMarketPl => 'Polskie';

  @override
  String get lobbyEmojiDifficulty => 'Trudność';

  @override
  String get lobbyEmojiDifficultyEasy => 'Łatwe';

  @override
  String get lobbyEmojiDifficultyMedium => 'Do średnich';

  @override
  String get lobbyEmojiDifficultyHard => 'Wszystkie, też trudne';

  @override
  String get lobbyEmojiHint => 'Bez muzyki: wystarczą telefony';

  @override
  String get gameYouTubePressPlay =>
      'Naciśnij ▶ w odtwarzaczu. Jeśli YouTube najpierw pokaże reklamę, poczekaj na piosenkę';

  @override
  String get gameYouTubeTapWhenPlaying =>
      'Gdy zabrzmi piosenka, naciśnij przycisk poniżej';

  @override
  String get gameYouTubeConsentTitle => 'Włączyć odtwarzacz YouTube?';

  @override
  String get gameYouTubeConsentBody =>
      'Piosenka zagra w oficjalnym odtwarzaczu YouTube. Podczas ładowania YouTube (Google) otrzymuje dane o Twoim urządzeniu i może pokazać reklamę.';

  @override
  String get gameYouTubeConsentAllow => 'Zezwól';

  @override
  String get gameYouTubeConsentDecline => 'Nie, włączę sam';

  @override
  String get gameYouTubeFallback => 'Wideo nie działa — włącz piosenkę sam';

  @override
  String get gameYouTubeDeclined =>
      'Bez YouTube: włącz piosenkę w swojej aplikacji';

  @override
  String get mySongsYouTubeAdd => 'Wideo YouTube';

  @override
  String mySongsYouTubeTitle(String song) {
    return 'Wideo do piosenki „$song”';
  }

  @override
  String get mySongsYouTubeHint =>
      'Wklej link do oficjalnego wideo piosenki — gdy będziesz DJ-em, zagra w odtwarzaczu YouTube';

  @override
  String get mySongsYouTubeField => 'Link do YouTube';

  @override
  String get mySongsYouTubePaste => 'Wklej';

  @override
  String get mySongsYouTubeCheck => 'Sprawdź';

  @override
  String get mySongsYouTubeUse => 'Połącz';

  @override
  String get mySongsYouTubeCancel => 'Anuluj';

  @override
  String get mySongsYouTubeRemove => 'Usuń wideo';

  @override
  String get mySongsYouTubeInvalid => 'To nie jest link do wideo YouTube';

  @override
  String get mySongsYouTubeNotFound =>
      'Nie znaleziono wideo albo jest prywatne';

  @override
  String get mySongsYouTubeNotEmbeddable =>
      'Autor nie pozwala na odtwarzanie tego wideo w aplikacjach';

  @override
  String get mySongsYouTubeFailed => 'Nie udało się sprawdzić linku';

  @override
  String get mySongsYouTubeLinked => 'Połączono wideo YouTube';

  @override
  String mySongsYouTubeChannel(String channel) {
    return 'Kanał: $channel';
  }
}
