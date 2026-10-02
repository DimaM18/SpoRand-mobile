import 'package:mobile_kit/mobile_kit.dart' show KitButton;

/// The hero action, one per screen: «Создать комнату», «Начать игру»,
/// «Сыграть ещё» (design system §6.3): mobile_kit's [KitButton] (wave 8b)
/// on the theme's `KitBrand` (the «Neon Night+» CTA gradient, text and
/// glow of `PartyColors`).
///
/// Not a timed input: answers and the DJ tap are `TimedTapTarget`s.
typedef PartyButton = KitButton;
