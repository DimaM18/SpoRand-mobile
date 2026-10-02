import 'package:mobile_kit/mobile_kit.dart' show KitChip, KitStatusChip;

/// A selectable setting chip (design system §6.5): mobile_kit's [KitChip]
/// (wave 8b), 40 dp visual inside a 48 dp hit area, the state never resting
/// on colour alone.
typedef PartyChip = KitChip;

/// A non-interactive status chip (bonus round, streak, trial):
/// mobile_kit's [KitStatusChip].
typedef StatusChip = KitStatusChip;
