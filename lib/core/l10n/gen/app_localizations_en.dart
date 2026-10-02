// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Music Party';

  @override
  String get bootLabelConfig => 'Loading settings…';

  @override
  String get bootLabelWarmup => 'Getting the sounds ready…';

  @override
  String get bootLabelSdk => 'Connecting services…';

  @override
  String get bootLabelEnter => 'Let\'s go!';

  @override
  String bootProgressSemantics(int percent) {
    return 'Loading: $percent%';
  }

  @override
  String get bootFailedTitle => 'Couldn\'t start';

  @override
  String get bootFailedBody => 'Check your connection and try again.';

  @override
  String get bootRetry => 'Try again';

  @override
  String get forceUpdateTitle => 'Time to update';

  @override
  String get forceUpdateBody =>
      'This version is no longer supported. Update the app to keep playing.';

  @override
  String get forceUpdateAction => 'Update';

  @override
  String get maintenanceTitle => 'Short break';

  @override
  String get maintenanceBody =>
      'We\'re tuning our servers. We\'ll be back soon — check again in a few minutes.';

  @override
  String get maintenanceRetry => 'Check again';

  @override
  String get onboardingAgeTitle => 'Year of birth';

  @override
  String get onboardingAgeSubtitle =>
      'We use it to set the app up for your age.';

  @override
  String get onboardingAgeFieldLabel => 'Year';

  @override
  String get onboardingAgeFieldHint => 'YYYY';

  @override
  String get onboardingAgeInvalid => 'Enter a four-digit year';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingBlockedTitle => 'Not yet';

  @override
  String get onboardingBlockedBody =>
      'This app is for players aged 13 and over.';

  @override
  String get onboardingConsentTitle => 'Your privacy';

  @override
  String get onboardingConsentBody =>
      'We never send your music to analytics or ads. You can help us improve the game with anonymous usage stats — it\'s optional and you can change it in settings.';

  @override
  String get onboardingConsentAnalytics => 'Share anonymous usage stats';

  @override
  String get onboardingConsentMinorNote =>
      'Usage stats are off for players under 16.';

  @override
  String get onboardingConsentStart => 'Start playing';

  @override
  String get homeHeadline => 'Whose song is it?';

  @override
  String get homeSubtitle =>
      'A party game for friends: hear a snippet, guess faster than everyone.';

  @override
  String get homeCreateRoom => 'Create a room';

  @override
  String get homeJoinTitle => 'Got a room code?';

  @override
  String get homeJoinCodeLabel => '6-character code';

  @override
  String get homeJoinAction => 'Join';

  @override
  String get homeJoinCodeInvalid => 'The code is 6 letters and digits';

  @override
  String get homeRemoveAds => 'Play without ads';

  @override
  String get homeSettingsTooltip => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsPrivacySection => 'Privacy';

  @override
  String get settingsAnalyticsTitle => 'Anonymous usage stats';

  @override
  String get settingsAnalyticsSubtitle =>
      'Helps us find bugs and improve the game';

  @override
  String get settingsAnalyticsUnavailable =>
      'Not available for players under 16';

  @override
  String get settingsPrivacyOptions => 'Ads and consent choices';

  @override
  String get settingsPurchasesSection => 'Purchases';

  @override
  String get settingsRemoveAds => 'Remove ads';

  @override
  String get settingsRestorePurchases => 'Restore purchases';

  @override
  String get settingsRestoreDone => 'Purchases restored';

  @override
  String get settingsRestoreNothing => 'No purchases found';

  @override
  String get settingsRestoreFailed => 'Couldn\'t restore purchases';

  @override
  String get settingsAboutSection => 'About';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String settingsDegraded(String steps) {
    return 'Limited mode: $steps';
  }

  @override
  String get settingsTerms => 'Terms of use';

  @override
  String get settingsPrivacyPolicy => 'Privacy policy';

  @override
  String get paywallTitle => 'Play without limits';

  @override
  String get paywallSubtitle => 'More rounds, more friends, no ads.';

  @override
  String get paywallPerkNoAds => 'No ads after games';

  @override
  String get paywallPerkRounds => 'Up to 50 rounds per game';

  @override
  String get paywallPerkPlayers => 'Up to 12 players per room';

  @override
  String get paywallRemoveAds => 'Remove ads';

  @override
  String paywallRemoveAdsDetail(String price) {
    return 'One-time purchase — $price';
  }

  @override
  String get paywallPremiumMonthly => 'Premium monthly';

  @override
  String get paywallPremiumYearly => 'Premium yearly';

  @override
  String paywallPerMonth(String price) {
    return '$price per month';
  }

  @override
  String paywallPerYear(String price) {
    return '$price per year';
  }

  @override
  String paywallTrial(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days-day free trial',
      one: '$days-day free trial',
    );
    return '$_temp0';
  }

  @override
  String get paywallBuy => 'Continue';

  @override
  String get paywallRestore => 'Restore purchases';

  @override
  String get paywallLegal =>
      'Subscriptions renew automatically unless cancelled in your store settings at least 24 hours before the end of the period. Payment is charged to your store account.';

  @override
  String get paywallUnavailable => 'Purchases are unavailable right now';

  @override
  String get paywallLoadFailed => 'Couldn\'t load offers';

  @override
  String get paywallRetry => 'Retry';

  @override
  String get paywallPurchased => 'Done! Thanks for your support';

  @override
  String get paywallPending => 'Your purchase is pending approval';

  @override
  String get paywallFailed => 'The purchase didn\'t go through';

  @override
  String get paywallOwned => 'Already purchased';

  @override
  String get placeholderBody => 'This screen arrives in the next build.';

  @override
  String joinTitle(String code) {
    return 'Room $code';
  }

  @override
  String get notFoundTitle => 'Page not found';

  @override
  String get notFoundAction => 'Go home';

  @override
  String get createRoomTitle => 'New room';

  @override
  String get createRoomModeLabel => 'Game mode';

  @override
  String get modeWhoseSong => 'Whose song is it?';

  @override
  String get modeWhoseSongHint => 'Guess whose music the snippet is from';

  @override
  String get modeGuessTrack => 'Guess the track';

  @override
  String get modeGuessTrackHint => 'Four options: name the song';

  @override
  String get displayNameLabel => 'Your name in the game';

  @override
  String get displayNameInvalid => '2 to 20 characters';

  @override
  String get createRoomAction => 'Create room';

  @override
  String get joinSubtitle => 'What should we call you?';

  @override
  String get joinAction => 'Join room';

  @override
  String get roomErrorNotFound => 'Room not found. Check the code';

  @override
  String get roomErrorFull => 'The room is full';

  @override
  String get roomErrorLocked => 'The game has started. Wait for the results';

  @override
  String get roomErrorRateLimited => 'Too many attempts. Wait a minute';

  @override
  String get roomErrorNetwork => 'No connection to the server';

  @override
  String get roomErrorOther => 'Something went wrong. Try again';

  @override
  String get lobbyTitle => 'Lobby';

  @override
  String get lobbyCodeLabel => 'Room code';

  @override
  String get lobbyShare => 'Invite';

  @override
  String get lobbyCopyLink => 'Copy link';

  @override
  String get lobbyLinkCopied => 'Link copied';

  @override
  String lobbyShareText(String code, String link) {
    return 'Join the game! Room code: $code\n$link';
  }

  @override
  String lobbyShareTextNoLink(String code) {
    return 'Join the game! Room code: $code';
  }

  @override
  String lobbyQrSemantics(String code) {
    return 'QR code to join room $code';
  }

  @override
  String lobbyPlayersTitle(int count) {
    return 'Players: $count';
  }

  @override
  String get lobbyHostBadge => 'Host';

  @override
  String get lobbyYouBadge => 'You';

  @override
  String get lobbyReady => 'Ready';

  @override
  String get lobbyNotReady => 'Not ready';

  @override
  String get lobbyAway => 'Reconnecting';

  @override
  String get lobbyConnecting => 'Connecting to the room…';

  @override
  String get lobbyReconnecting => 'Connection lost. Reconnecting…';

  @override
  String get lobbySettingsTitle => 'Game settings';

  @override
  String get lobbyRoundsLabel => 'Rounds';

  @override
  String lobbyRoundsLocked(int count) {
    return '$count rounds with Premium';
  }

  @override
  String get lobbyStart => 'Start the game';

  @override
  String lobbyNeedPlayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'At least $count players needed',
      one: 'At least $count player needed',
    );
    return '$_temp0';
  }

  @override
  String lobbyNeedContributors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more players need to add songs',
      one: '$count more player needs to add songs',
    );
    return '$_temp0';
  }

  @override
  String get lobbyWaitingForHost => 'The host will start the game soon';

  @override
  String get lobbyImReady => 'I\'m ready';

  @override
  String get lobbyKick => 'Remove from room';

  @override
  String get lobbyReport => 'Report';

  @override
  String get lobbyReportTitle => 'Reason for the report';

  @override
  String get reportReasonName => 'Offensive name';

  @override
  String get reportReasonCheating => 'Cheating';

  @override
  String get reportReasonHarassment => 'Harassment';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get lobbyReportSent => 'Report sent. Thank you!';

  @override
  String get lobbyReportFailed => 'Could not send the report';

  @override
  String get lobbyLeave => 'Leave';

  @override
  String get lobbyLeaveConfirmTitle => 'Leave the room?';

  @override
  String get lobbyLeaveConfirmBody =>
      'You can come back with the same code until the game starts.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get lobbyNoRoom => 'You are not in a room';

  @override
  String get lobbyBackHome => 'Back to home';

  @override
  String get roomEndedKicked => 'The host removed you from the room';

  @override
  String get roomEndedClosed => 'The room was closed';

  @override
  String get roomEndedReplaced => 'You opened this room on another device';

  @override
  String get roomEndedVersion => 'Update the app to play';

  @override
  String get roomEndedLost => 'Could not reconnect to the room';

  @override
  String get errorNotHost => 'Only the host can do that';

  @override
  String get errorPoolInsufficient => 'Players do not have enough songs';

  @override
  String get errorTierRequired => 'This setting needs Premium';

  @override
  String get errorPlaybackUnavailable => 'The host\'s phone cannot play music';

  @override
  String get errorInvalidState => 'You can\'t do that right now';

  @override
  String get errorRateLimited => 'Too fast. Wait a second';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get gameWaiting => 'Waiting for the game to start…';

  @override
  String get gameStartingTitle => 'Get ready!';

  @override
  String gameStartingRounds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rounds',
      one: '$count round',
    );
    return '$_temp0';
  }

  @override
  String gameRoundOf(int current, int total) {
    return 'Round $current of $total';
  }

  @override
  String get gameBonusRound => 'Bonus round';

  @override
  String get gamePromptWhoseSong => 'Whose song is it?';

  @override
  String get gamePromptGuessTrack => 'What\'s the track?';

  @override
  String get gameListen => 'Listen…';

  @override
  String get gameTapFast => 'Tap faster than everyone!';

  @override
  String get gameYourTrack => 'This is your track!';

  @override
  String get gameYourTrackHint => 'Watch who gets it';

  @override
  String get gameAnswerSent => 'Answer sent';

  @override
  String get gameAnswerAccepted => 'Answer locked in!';

  @override
  String get gameAnswerRejected => 'Answer not counted';

  @override
  String get gameTimeUp => 'Time\'s up';

  @override
  String gameProgress(int answered, int eligible) {
    return '$answered of $eligible answered';
  }

  @override
  String get gameAirplayWarning =>
      'AirPlay delays the sound by about 2 seconds. The phone speaker works better.';

  @override
  String revealCorrect(int points) {
    return 'Correct! +$points';
  }

  @override
  String get revealWrong => 'Missed';

  @override
  String get revealNoAnswer => 'No answer';

  @override
  String get revealOwnerYou => 'It was your track';

  @override
  String revealReaction(String seconds) {
    return 'Reaction: $seconds s';
  }

  @override
  String revealOwner(String names) {
    return 'It\'s the track of: $names';
  }

  @override
  String revealAnswer(String label) {
    return 'Answer: $label';
  }

  @override
  String get revealStandings => 'Standings';

  @override
  String revealGained(int points) {
    return '+$points';
  }

  @override
  String pointsShort(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points pts',
      one: '$points pt',
    );
    return '$_temp0';
  }

  @override
  String get gameVoided => 'Round cancelled: a spare round is next';

  @override
  String get gameVoidedPlayback => 'The music could not start';

  @override
  String get gameVoidedHost => 'The host disconnected';

  @override
  String get gameVoidedServer => 'The server restarted';

  @override
  String get gamePaused => 'Waiting for the host…';

  @override
  String get gamePausedHint => 'The game continues when the host is back';

  @override
  String get bonusOfferTitle => 'Watch an ad: +1 round for everyone';

  @override
  String get bonusOfferAction => 'Watch';

  @override
  String get bonusOfferWaiting => 'Bonus round? Someone can watch an ad';

  @override
  String bonusSponsorWatching(String name) {
    return '$name is watching an ad…';
  }

  @override
  String get bonusYouWatching => 'Getting the ad ready…';

  @override
  String get bonusVerifying => 'Checking the reward…';

  @override
  String bonusGranted(String name) {
    return '+1 round for everyone! Thanks, $name';
  }

  @override
  String get bonusCancelled => 'No bonus round this time';

  @override
  String get bonusCancelledSsv => 'We could not confirm the ad view. Sorry!';

  @override
  String get adBreakCounting => 'Counting the points…';

  @override
  String get upsellTitle => 'Play without ads';

  @override
  String upsellPrice(String price) {
    return 'Play without ads: $price';
  }

  @override
  String get upsellAction => 'Learn more';

  @override
  String get resultsTitle => 'Results';

  @override
  String get resultsPlayAgain => 'Play again';

  @override
  String get resultsWaitingHost => 'The host can start a new game';

  @override
  String resultsRounds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rounds played',
      one: '$count round played',
    );
    return '$_temp0';
  }

  @override
  String get resultsBonusUsed => 'With a bonus round';

  @override
  String resultsCorrect(int count) {
    return 'Correct: $count';
  }

  @override
  String get settingsClockCalibration => 'Clock calibration (developers)';

  @override
  String get gameDjStarting => 'The host is starting the song…';

  @override
  String get gameDjCueTitle => 'Play this song in your music app';

  @override
  String get gameDjCueSecret =>
      'Only you can see the title — keep your screen to yourself';

  @override
  String get gameDjOpenApp => 'Open in music app';

  @override
  String get gameDjOpenAppFailed =>
      'Couldn\'t open a music app — find the song manually';

  @override
  String get gameDjMusicPlaying => 'Music is playing!';

  @override
  String get gameDjMusicPlayingHint => 'Tap as soon as the song starts';

  @override
  String get gameDjWatchingTitle => 'You\'re the DJ!';

  @override
  String get gameDjWatchingHint => 'The guests answer this round';

  @override
  String get gameAnswerRejectedDj => 'The DJ doesn\'t answer this round';

  @override
  String get gameTextRoundHint => 'No music this round: read and guess';

  @override
  String get gameTextRoundLocked => 'Get ready…';

  @override
  String get homeMySongs => 'My songs';

  @override
  String get mySongsTitle => 'My songs';

  @override
  String get mySongsSearchLabel => 'Song or artist';

  @override
  String get mySongsSearchEmpty => 'Nothing found';

  @override
  String get mySongsSearchFailed => 'Search failed. Check your connection.';

  @override
  String mySongsSelected(int count, int max) {
    return '$count of $max selected';
  }

  @override
  String mySongsNeedMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count more songs',
      one: 'Add $count more song',
    );
    return '$_temp0';
  }

  @override
  String mySongsFull(int max) {
    return 'You can pick up to $max songs';
  }

  @override
  String get mySongsSave => 'Save';

  @override
  String get mySongsSaved => 'Songs saved';

  @override
  String get mySongsSaveFailed => 'Couldn\'t save';

  @override
  String get mySongsLoadFailed => 'Couldn\'t load your songs';

  @override
  String mySongsEmpty(int min, int max) {
    return 'Find $min to $max favourite songs — friends will guess whose they are';
  }

  @override
  String get mySongsAdd => 'Add';

  @override
  String get mySongsRemove => 'Remove';

  @override
  String get mySongsPreviewTitle => 'What friends will see';

  @override
  String get mySongsPreviewBody =>
      'If one of your songs comes up, everyone sees its title, artist and that it\'s yours. Nobody ever sees your whole list.';

  @override
  String get lobbyAddMySongs => 'Add my songs';

  @override
  String get lobbyUpdateMySongs => 'Update my songs';

  @override
  String get lobbyOpenMySongs => 'Open My songs';

  @override
  String get lobbyPoolConsentBody =>
      'These songs will be shown to the room as yours';

  @override
  String get lobbyPoolConsentConfirm => 'Confirm';

  @override
  String get lobbyPoolSent => 'Your songs are in the game';

  @override
  String get lobbyPoolFailed => 'Couldn\'t add your songs';

  @override
  String lobbyPoolNeedPicks(int min) {
    return 'First pick at least $min songs in My songs';
  }

  @override
  String lobbyPoolTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '$count song',
    );
    return '$_temp0';
  }

  @override
  String lobbyPoolTooSmall(String name, int min) {
    return '$name has fewer than $min songs';
  }

  @override
  String get lobbyNeedAnyPool => 'At least one player needs to add songs';

  @override
  String get lobbyDjHint =>
      'You\'re the DJ: play the songs in your own music app, loud on a speaker';

  @override
  String get mySongsLegacyHint =>
      'Songs from the old catalogue need to be replaced';

  @override
  String get modeEmojiQuiz => 'Guess the song';

  @override
  String get modeEmojiQuizHint => 'Guess the song from emoji — no music needed';

  @override
  String get gamePromptEmoji => 'Which song is it?';

  @override
  String get gameEmojiHidden => 'The emoji appear at the start';

  @override
  String gameEmojiSemantics(String emoji) {
    return 'Emoji: $emoji';
  }

  @override
  String revealYear(String year) {
    return 'Year: $year';
  }

  @override
  String gameDjStartingNamed(String name) {
    return '$name is starting the song…';
  }

  @override
  String get gameDjRoundNoAnswer =>
      'You\'re this round\'s DJ — the others answer';

  @override
  String gameVoidedNotice(String reason) {
    return 'Round skipped: $reason';
  }

  @override
  String get gameVoidedNoticeNoReason => 'Round skipped';

  @override
  String get lobbyCanDj => 'I can play the music';

  @override
  String get lobbyCanDjHint =>
      'Sometimes you\'ll be the DJ: play the song in your own music app';

  @override
  String get lobbyDjBadge => 'DJ';

  @override
  String get lobbyEmojiMarkets => 'Songs';

  @override
  String get lobbyEmojiMarketIntl => 'International';

  @override
  String get lobbyEmojiMarketPl => 'Polish';

  @override
  String get lobbyEmojiMarketCis => 'CIS';

  @override
  String lobbyEmojiRetro(String year) {
    return 'Retro (before $year)';
  }

  @override
  String get lobbyEmojiDifficulty => 'Difficulty';

  @override
  String get lobbyEmojiDifficultyEasy => 'Easy';

  @override
  String get lobbyEmojiDifficultyMedium => 'Up to medium';

  @override
  String get lobbyEmojiDifficultyHard => 'All, hard ones too';

  @override
  String get lobbyEmojiHint => 'No music: phones are enough';

  @override
  String gameYouTubePressPlay(String playIcon) {
    return 'Press $playIcon in the player. If YouTube shows an ad first, wait for the song';
  }

  @override
  String get gameYouTubePlayButton => 'the play button';

  @override
  String get gameYouTubeConsentTitle => 'Turn on the YouTube player?';

  @override
  String get gameYouTubeConsentBody =>
      'The song plays in the official YouTube player. When it loads, YouTube (Google) receives data about your device and may show ads.';

  @override
  String get gameYouTubeConsentAllow => 'Allow';

  @override
  String get gameYouTubeConsentDecline => 'No, I\'ll play it myself';

  @override
  String get gameYouTubeFallback =>
      'The video won\'t play — start the song yourself';

  @override
  String get gameYouTubeWindowTooSmall =>
      'The window is too small for the YouTube player. Make it bigger or start the song yourself';

  @override
  String get gameYouTubeDeclined =>
      'Without YouTube: play the song in your own app';

  @override
  String get mySongsYouTubeAdd => 'YouTube video';

  @override
  String mySongsYouTubeTitle(String song) {
    return 'Video for “$song”';
  }

  @override
  String get mySongsYouTubeHint =>
      'Paste a link to the song\'s official video: when you are the DJ, it plays in the YouTube player';

  @override
  String get mySongsYouTubeField => 'YouTube link';

  @override
  String get mySongsYouTubePaste => 'Paste';

  @override
  String get mySongsYouTubeCheck => 'Check';

  @override
  String get mySongsYouTubeUse => 'Link';

  @override
  String get mySongsYouTubeCancel => 'Cancel';

  @override
  String get mySongsYouTubeRemove => 'Remove video';

  @override
  String get mySongsYouTubeInvalid => 'This is not a YouTube video link';

  @override
  String get mySongsYouTubeNotFound => 'Video not found or private';

  @override
  String get mySongsYouTubeNotEmbeddable =>
      'The owner does not allow this video in apps';

  @override
  String get mySongsYouTubeFailed => 'Could not check the link';

  @override
  String get mySongsYouTubeLinked => 'YouTube video linked';

  @override
  String mySongsYouTubeChannel(String channel) {
    return 'Channel: $channel';
  }

  @override
  String get gameMarkerCircle => 'Circle';

  @override
  String get gameMarkerTriangle => 'Triangle';

  @override
  String get gameMarkerSquare => 'Square';

  @override
  String get gameMarkerDiamond => 'Diamond';

  @override
  String get gameMarkerHexagon => 'Hexagon';

  @override
  String get gameMarkerStar => 'Star';

  @override
  String gameAnswerSemantics(String marker, String option) {
    return '$marker: $option';
  }

  @override
  String get gameYourPick => 'Your answer';

  @override
  String get gameTileCorrect => 'Correct';

  @override
  String gameTimeLeftSemantics(int seconds) {
    return '$seconds s left';
  }

  @override
  String revealStreak(int count) {
    return 'Streak ×$count';
  }

  @override
  String get playerBadgeHost => 'Host';

  @override
  String get playerBadgeDj => 'DJ';

  @override
  String get playerBadgeReady => 'Ready';

  @override
  String get gameDjTapped => 'Marked';

  @override
  String get gameLeaveInlineConfirm => 'Leave the game?';

  @override
  String get gameLeaveInlineCancel => 'Stay';

  @override
  String get lobbyCopyCode => 'Copy code';

  @override
  String get lobbyCodeCopied => 'Code copied';

  @override
  String onboardingStepSemantics(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String standingsMovedUp(int n) {
    return 'up $n';
  }

  @override
  String standingsMovedDown(int n) {
    return 'down $n';
  }

  @override
  String resultsPodiumSemantics(int rank, String name, String points) {
    return 'Place $rank: $name, $points';
  }
}
