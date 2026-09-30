/// `paywall_view.placement` (brief §4.5).
enum PaywallPlacement {
  lobbyRounds('lobby_rounds'),
  lobbyPlayers('lobby_players'),
  settings('settings'),
  adBreak('ad_break');

  const PaywallPlacement(this.wireName);

  final String wireName;

  static PaywallPlacement fromWire(String? raw) {
    for (final placement in values) {
      if (placement.wireName == raw) return placement;
    }
    return PaywallPlacement.settings;
  }
}
