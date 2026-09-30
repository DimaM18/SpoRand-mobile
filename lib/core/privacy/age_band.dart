/// `User.age_band` (brief §4.1) and the policy that follows from it (§7).
enum AgeBand {
  under13('under_13'),
  age13to15('13_15'),
  age16to17('16_17'),
  adult('18_plus');

  const AgeBand(this.wireName);

  final String wireName;

  static AgeBand? fromWire(String? raw) {
    for (final band in values) {
      if (band.wireName == raw) return band;
    }
    return null;
  }

  static AgeBand fromAge(int age) {
    if (age < 13) return AgeBand.under13;
    if (age < 16) return AgeBand.age13to15;
    if (age < 18) return AgeBand.age16to17;
    return AgeBand.adult;
  }

  /// Under 13 the app is blocked (13+ rating, Q11).
  bool get isBlocked => this == AgeBand.under13;

  /// Below the GDPR Art. 8 threshold of 16 used for Poland.
  bool get isUnderAgeOfConsent => this == AgeBand.under13 || this == age13to15;

  /// 13-15: no analytics consent is asked and analytics stays off. We apply
  /// this everywhere, not only in the EEA, because the client cannot know the
  /// user's region reliably before UMP runs.
  bool get allowsAnalytics => !isUnderAgeOfConsent;

  bool get allowsAds => !isBlocked;

  /// 13-15 get non-personalized ads only (`tagForUnderAgeOfConsent`).
  bool get allowsPersonalizedAds => !isUnderAgeOfConsent;
}
