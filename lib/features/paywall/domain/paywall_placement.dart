/// `paywall_view.placement`: the wire string itself (wave 8b: mobile_kit's
/// paywall placements are strings, `PaywallConfig.placements`).
extension type const PaywallPlacement._(String wireName) implements Object {
  static const lobbyRounds = PaywallPlacement._('lobby_rounds');
  static const lobbyPlayers = PaywallPlacement._('lobby_players');
  static const settings = PaywallPlacement._('settings');
  static const adBreak = PaywallPlacement._('ad_break');

  static const values = [lobbyRounds, lobbyPlayers, settings, adBreak];

  /// An unknown or missing value falls back to [settings], so it never
  /// reaches analytics.
  static PaywallPlacement fromWire(String? raw) {
    for (final placement in values) {
      if (placement.wireName == raw) return placement;
    }
    return PaywallPlacement.settings;
  }
}
