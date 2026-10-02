import 'package:mobile_kit/mobile_kit.dart' show KitCard, KitCardTone;

export 'package:mobile_kit/mobile_kit.dart' show GradientHeadline;

/// A flat, tonal card (design system §6.4): mobile_kit's [KitCard] (wave
/// 8b). Elevation is tonal, never a shadow. Not tappable by itself: put
/// buttons inside.
typedef PartyCard = KitCard;

/// The fill of a [PartyCard]; `cta` is the text-safe hero fill for banner
/// cards such as «Это твой трек!» and the bonus offer.
typedef PartyCardTone = KitCardTone;
