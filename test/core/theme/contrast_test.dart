import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/theme/app_theme.dart';
import 'package:sporand/core/theme/tokens.dart';

/// WCAG 2.x contrast ratio.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [top] composited over the opaque [bottom].
Color over(Color top, Color bottom) => Color.alphaBlend(top, bottom);

const _text = 4.5;
const _nonText = 3.0;

void main() {
  for (final (name, scheme, party, game) in [
    ('dark', AppTheme.darkScheme, PartyColors.dark, GameColors.dark),
    ('light', AppTheme.lightScheme, PartyColors.light, GameColors.light),
  ]) {
    group('$name theme', () {
      void check(String pair, Color fg, Color bg, double min) {
        expect(
          contrast(fg, bg),
          greaterThanOrEqualTo(min),
          reason: '$name $pair: ${contrast(fg, bg).toStringAsFixed(2)}:1',
        );
      }

      test('scheme text pairs are AA', () {
        final s = scheme;
        check('onSurface/surface', s.onSurface, s.surface, _text);
        for (final (label, bg) in [
          ('surface', s.surface),
          ('surfaceContainer', s.surfaceContainer),
          ('surfaceContainerHigh', s.surfaceContainerHigh),
          ('surfaceContainerHighest', s.surfaceContainerHighest),
        ]) {
          check('onSurface/$label', s.onSurface, bg, _text);
          check('onSurfaceVariant/$label', s.onSurfaceVariant, bg, _text);
        }
        check('onPrimary/primary', s.onPrimary, s.primary, _text);
        check(
          'onPrimaryContainer/primaryContainer',
          s.onPrimaryContainer,
          s.primaryContainer,
          _text,
        );
        check(
          'onSecondaryContainer/secondaryContainer',
          s.onSecondaryContainer,
          s.secondaryContainer,
          _text,
        );
        check(
          'onTertiaryContainer/tertiaryContainer',
          s.onTertiaryContainer,
          s.tertiaryContainer,
          _text,
        );
        check(
          'onErrorContainer/errorContainer',
          s.onErrorContainer,
          s.errorContainer,
          _text,
        );
        check('error text/surface', s.error, s.surface, _text);
        check(
          'onInverseSurface/inverseSurface',
          s.onInverseSurface,
          s.inverseSurface,
          _text,
        );
        check(
          'inversePrimary (SnackBar action)/inverseSurface',
          s.inversePrimary,
          s.inverseSurface,
          _text,
        );
      });

      test('non-text pairs are at least 3:1', () {
        final s = scheme;
        check('outline/surface', s.outline, s.surface, _nonText);
        check('outline/surfaceContainer', s.outline, s.surfaceContainer, 3);
        check('primary (focus, me ring)/surface', s.primary, s.surface, 3);
        final track = over(party.ringTrack, s.surface);
        check('timer arc/track', s.primary, track, _nonText);
        check('urgent arc/track', game.timerUrgent, track, _nonText);
      });

      test('control boundaries and states are at least 3:1 (WCAG 1.4.11)', () {
        final s = scheme;
        final theme = name == 'dark' ? AppTheme.dark() : AppTheme.light();
        // A text field's edge against every container it sits on (page,
        // card, sheet or dialog) and against its own fill.
        final field = theme.inputDecorationTheme.enabledBorder!.borderSide;
        expect(field.style, BorderStyle.solid, reason: 'a visible edge');
        for (final (label, bg) in [
          ('surface', s.surface),
          ('surfaceContainer', s.surfaceContainer),
          ('surfaceContainerHigh', s.surfaceContainerHigh),
          ('field fill', theme.inputDecorationTheme.fillColor!),
        ]) {
          check('text field edge/$label', field.color, bg, _nonText);
        }
        // The off switch: its thumb against the default M3 track.
        final thumb = theme.switchTheme.thumbColor!.resolve({})!;
        check('off switch thumb/track', thumb, s.surfaceContainerHighest, 3);
        // Inactive onboarding step pills use outline on the page.
        check('outline (step pill)/surface', s.outline, s.surface, 3);
        check(
          'outline/surfaceContainerHigh',
          s.outline,
          s.surfaceContainerHigh,
          3,
        );
      });

      test('onCta is AA across the whole ctaGradient, also pressed', () {
        final stops = party.ctaGradient;
        for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
          final color = Color.lerp(stops.first, stops.last, t)!;
          check('onCta/cta@$t', party.onCta, color, _text);
          check(
            'onCta/cta pressed@$t',
            party.onCta,
            over(Colors.black.withValues(alpha: 0.12), color),
            _text,
          );
        }
      });

      test('headlineGradient text is AA on the surface along the ramp', () {
        final stops = party.headlineGradient;
        for (var k = 0; k + 1 < stops.length; k++) {
          for (var step = 0; step <= 10; step++) {
            final color = Color.lerp(stops[k], stops[k + 1], step / 10)!;
            check(
              'headline $k+${step / 10}/surface',
              color,
              scheme.surface,
              _text,
            );
          }
        }
      });

      test('answer slots: full fills, tonal idle fills and borders', () {
        for (var i = 0; i < GameColors.slots; i++) {
          final a = game.answer(i);
          check('onAnswer$i/answer$i', a.on, a.fill, _text);
          check('onSurface/tonal$i', scheme.onSurface, a.tonal, _text);
          final pressed = over(
            scheme.onSurface.withValues(
              alpha: scheme.brightness == Brightness.dark ? 0.08 : 0.06,
            ),
            a.tonal,
          );
          check('onSurface/tonal$i pressed', scheme.onSurface, pressed, _text);
          check('answer$i border/surface', a.fill, scheme.surface, _nonText);
        }
      });

      test('game state colours are AA as fills and as text', () {
        check('onCorrect/correct', game.onCorrect, game.correct, _text);
        check('onWrong/wrong', game.onWrong, game.wrong, _text);
        for (final (label, bg) in [
          ('surface', scheme.surface),
          ('surfaceContainer', scheme.surfaceContainer),
        ]) {
          check('correct text/$label', game.correct, bg, _text);
          check('gold/$label', game.gold, bg, _text);
          check('timerUrgent/$label', game.timerUrgent, bg, _text);
          check('gained/$label', game.gained, bg, _text);
        }
      });
    });
  }

  test('the tonal fills are the documented mix of the answer colour', () {
    Color mix(Color c, Color base, double t) => Color.lerp(base, c, t)!;
    for (var i = 0; i < GameColors.slots; i++) {
      final dark = GameColors.dark.answer(i);
      final light = GameColors.light.answer(i);
      final darkMix = mix(dark.fill, AppTheme.darkScheme.surfaceContainer, .18);
      final lightMix = mix(light.fill, Colors.white, .12);
      for (final (want, got) in [
        (darkMix, dark.tonal),
        (lightMix, light.tonal),
      ]) {
        expect((want.r - got.r).abs() * 255, lessThanOrEqualTo(1));
        expect((want.g - got.g).abs() * 255, lessThanOrEqualTo(1));
        expect((want.b - got.b).abs() * 255, lessThanOrEqualTo(1));
      }
    }
  });
}
