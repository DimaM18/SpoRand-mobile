import 'package:material_ui/material_ui.dart';

/// One answer slot's colors: [fill] with [on] text (full fill: your pick,
/// markers, avatars) and the [tonal] idle fill that takes `onSurface` text.
typedef AnswerSwatch = ({Color fill, Color on, Color tonal});

/// Game colors the Material scheme has no slot for: six answer slots
/// (`options_count` is 2..6), right/wrong, leader gold, the urgent timer
/// and gained points. Every text pair is WCAG AA (see
/// `test/core/theme/contrast_test.dart`).
///
/// Colour is never the only signal: answers also carry a shape marker
/// (`AnswerMarker`) and states an icon plus a word.
@immutable
class GameColors extends ThemeExtension<GameColors> {
  const GameColors({
    required this.answers,
    required this.onAnswers,
    required this.answerTonals,
    required this.correct,
    required this.onCorrect,
    required this.wrong,
    required this.onWrong,
    required this.gold,
    required this.timerUrgent,
    required this.gained,
  });

  /// Answer slots; every list holds exactly this many colors.
  static const slots = 6;

  static const dark = GameColors(
    // violet, magenta, cyan, amber, blue, orange
    answers: [
      Color(0xFFA594FF),
      Color(0xFFFF5CA8),
      Color(0xFF3DDCFF),
      Color(0xFFFFC24B),
      Color(0xFF7FB2FF),
      Color(0xFFFF9A5C),
    ],
    onAnswers: [
      Color(0xFF1B1045),
      Color(0xFF3B0020),
      Color(0xFF002733),
      Color(0xFF2A1A00),
      Color(0xFF06183A),
      Color(0xFF2A0E00),
    ],
    // 18% of the answer color over surfaceContainer #1B1735.
    answerTonals: [
      Color(0xFF342E59),
      Color(0xFF44234A),
      Color(0xFF213A59),
      Color(0xFF443639),
      Color(0xFF2D3359),
      Color(0xFF442F3C),
    ],
    correct: Color(0xFF5BE38A),
    onCorrect: Color(0xFF00210C),
    wrong: Color(0xFFFF8A80),
    onWrong: Color(0xFF3A0000),
    gold: Color(0xFFFFC24B),
    timerUrgent: Color(0xFFFF8A80),
    gained: Color(0xFF3DDCFF),
  );

  static const light = GameColors(
    answers: [
      Color(0xFF5B3DF5),
      Color(0xFFC2186B),
      Color(0xFF00718F),
      Color(0xFF8A5A00),
      Color(0xFF1F5FD1),
      Color(0xFFB3470E),
    ],
    onAnswers: [
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
    ],
    // 12% of the answer color over white.
    answerTonals: [
      Color(0xFFEBE8FE),
      Color(0xFFF8E3ED),
      Color(0xFFE0EEF2),
      Color(0xFFF1EBE0),
      Color(0xFFE4ECF9),
      Color(0xFFF6E9E2),
    ],
    correct: Color(0xFF146C33),
    onCorrect: Color(0xFFFFFFFF),
    wrong: Color(0xFFBA1A1A),
    onWrong: Color(0xFFFFFFFF),
    gold: Color(0xFF8A5A00),
    timerUrgent: Color(0xFFB3261E),
    gained: Color(0xFF00718F),
  );

  final List<Color> answers;
  final List<Color> onAnswers;
  final List<Color> answerTonals;
  final Color correct;
  final Color onCorrect;
  final Color wrong;
  final Color onWrong;
  final Color gold;
  final Color timerUrgent;
  final Color gained;

  /// The swatch of answer slot [index] (wraps past [slots]).
  AnswerSwatch answer(int index) {
    final i = index % slots;
    return (fill: answers[i], on: onAnswers[i], tonal: answerTonals[i]);
  }

  static GameColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<GameColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  GameColors copyWith({
    List<Color>? answers,
    List<Color>? onAnswers,
    List<Color>? answerTonals,
    Color? correct,
    Color? onCorrect,
    Color? wrong,
    Color? onWrong,
    Color? gold,
    Color? timerUrgent,
    Color? gained,
  }) => GameColors(
    answers: answers ?? this.answers,
    onAnswers: onAnswers ?? this.onAnswers,
    answerTonals: answerTonals ?? this.answerTonals,
    correct: correct ?? this.correct,
    onCorrect: onCorrect ?? this.onCorrect,
    wrong: wrong ?? this.wrong,
    onWrong: onWrong ?? this.onWrong,
    gold: gold ?? this.gold,
    timerUrgent: timerUrgent ?? this.timerUrgent,
    gained: gained ?? this.gained,
  );

  @override
  GameColors lerp(GameColors? other, double t) {
    if (other == null) return this;
    List<Color> list(List<Color> a, List<Color> b) => [
      for (var i = 0; i < slots; i++) Color.lerp(a[i], b[i], t)!,
    ];
    return GameColors(
      answers: list(answers, other.answers),
      onAnswers: list(onAnswers, other.onAnswers),
      answerTonals: list(answerTonals, other.answerTonals),
      correct: Color.lerp(correct, other.correct, t)!,
      onCorrect: Color.lerp(onCorrect, other.onCorrect, t)!,
      wrong: Color.lerp(wrong, other.wrong, t)!,
      onWrong: Color.lerp(onWrong, other.onWrong, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      timerUrgent: Color.lerp(timerUrgent, other.timerUrgent, t)!,
      gained: Color.lerp(gained, other.gained, t)!,
    );
  }
}
