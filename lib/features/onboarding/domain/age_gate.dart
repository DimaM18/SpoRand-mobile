import 'dart:math' as math;

import 'package:sporand/core/privacy/age_band.dart';

sealed class AgeGateResult {
  const AgeGateResult();
}

/// Not a plausible four-digit year of birth.
final class AgeGateInvalid extends AgeGateResult {
  const AgeGateInvalid();
}

final class AgeGateAccepted extends AgeGateResult {
  const AgeGateAccepted(this.band);

  final AgeBand band;
}

/// Under 13: the app is blocked (brief §7 "Age", Q11).
final class AgeGateBlocked extends AgeGateResult {
  const AgeGateBlocked();
}

/// Neutral age gate: asks only for the year of birth and derives `age_band`.
final class AgeGate {
  const AgeGate({required this.currentYear, this.maxAge = 120});

  final int currentYear;
  final int maxAge;

  static final RegExp _year = RegExp(r'^\d{4}$');

  AgeGateResult evaluate(String input) {
    final trimmed = input.trim();
    if (!_year.hasMatch(trimmed)) return const AgeGateInvalid();
    final year = int.parse(trimmed);
    if (year > currentYear || year < currentYear - maxAge) {
      return const AgeGateInvalid();
    }
    final band = AgeBand.fromAge(minimumAge(year));
    return band.isBlocked ? const AgeGateBlocked() : AgeGateAccepted(band);
  }

  /// With only a year we cannot tell whether this year's birthday has
  /// passed, so we take the youngest possible age. A child is therefore never
  /// placed in an older band; the cost is that someone whose birthday is
  /// still ahead this year lands one band lower until it passes.
  int minimumAge(int birthYear) => math.max(0, currentYear - birthYear - 1);
}
