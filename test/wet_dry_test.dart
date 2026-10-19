import 'package:pigment_km/pigment_km.dart';
import 'package:pigment_km/src/tune/wet_dry.dart';
import 'package:test/test.dart';

/// Unit tests for the TUNE-4 wet→dry state transform (design §7 lever 3, AC-23).
///
/// The transform re-renders a predicted colour in its dry state from a
/// per-medium CIE L*C*h drying offset, without re-solving. These tests pin the
/// state-transform contract ([toDryState] carries every non-colour field
/// through unchanged) and the colour maths ([driedColour]: Y set by L* alone so
/// a negative lightness delta darkens; hue rotation and wrapping; chroma clamped
/// at 0), including the near-black CIELAB linear-segment path.
void main() {
  // A mid-tone bluish colour (CIELAB b* < 0, so its hue is negative before
  // normalization — the hue-wrap branch). The oklch field here is immaterial:
  // [driedColour] recomputes the whole triple from the transformed XYZ.
  const wet = ColourValue(
    srgb: (r: 0.45, g: 0.42, b: 0.55),
    xyz: (x: 0.25, y: 0.22, z: 0.30),
    oklch: (l: 0.6, c: 0.05, h: 280.0),
  );

  Recipe recipeWith(ColourValue colour) => Recipe(
        medium: Medium.acrylic,
        parts: const <String, double>{'a': 0.6, 'b': 0.4},
        colour: colour,
        deltaE00: 2.5,
        provenance: Provenance.calculated,
        outOfGamut: false,
        verdict: 'ΔE00 2.50',
      );

  double hueDiff(double a, double b) {
    var d = (a - b).abs() % 360;
    if (d > 180) {
      d = 360 - d;
    }
    return d;
  }

  group('driedColour', () {
    test('the identity transform returns the colour unchanged', () {
      expect(driedColour(wet, WetDryTransform.none), same(wet));
    });

    test('a negative lightness delta darkens the colour (lower Y)', () {
      final dry = driedColour(wet, const WetDryTransform(lightnessDelta: -3));
      expect(dry.xyz.y, lessThan(wet.xyz.y));
      // The whole triple is rebuilt consistently (displayable sRGB in range).
      expect(dry.srgb.r, inInclusiveRange(0.0, 1.0));
      expect(dry.srgb.g, inInclusiveRange(0.0, 1.0));
      expect(dry.srgb.b, inInclusiveRange(0.0, 1.0));
    });

    test('Y is a function of L* alone — chroma and hue deltas never move it',
        () {
      final lightnessOnly =
          driedColour(wet, const WetDryTransform(lightnessDelta: -3));
      final alsoChromaHue = driedColour(
          wet,
          const WetDryTransform(
              lightnessDelta: -3, chromaDelta: 4, hueDeltaDeg: 20));
      expect(alsoChromaHue.xyz.y, closeTo(lightnessOnly.xyz.y, 1e-9));
    });

    test('a hue delta rotates the hue measurably', () {
      final rotated = driedColour(wet, const WetDryTransform(hueDeltaDeg: 15));
      final unrotated =
          driedColour(wet, const WetDryTransform(chromaDelta: 0.0001));
      expect(hueDiff(rotated.oklch.h, unrotated.oklch.h), greaterThan(1.0));
    });

    test('a hue delta past 360° wraps (375° ≡ 15°)', () {
      final at15 = driedColour(wet, const WetDryTransform(hueDeltaDeg: 15));
      final at375 = driedColour(wet, const WetDryTransform(hueDeltaDeg: 375));
      expect(at375.xyz.x, closeTo(at15.xyz.x, 1e-9));
      expect(at375.xyz.y, closeTo(at15.xyz.y, 1e-9));
      expect(at375.xyz.z, closeTo(at15.xyz.z, 1e-9));
    });

    test('a negative hue delta wraps (−5° ≡ 355°)', () {
      final atMinus5 = driedColour(wet, const WetDryTransform(hueDeltaDeg: -5));
      final at355 = driedColour(wet, const WetDryTransform(hueDeltaDeg: 355));
      expect(atMinus5.xyz.x, closeTo(at355.xyz.x, 1e-9));
      expect(atMinus5.xyz.y, closeTo(at355.xyz.y, 1e-9));
      expect(atMinus5.xyz.z, closeTo(at355.xyz.z, 1e-9));
    });

    test('chroma is clamped at 0 — a large negative delta yields a neutral', () {
      final grey = driedColour(wet, const WetDryTransform(chromaDelta: -100));
      expect(grey.oklch.c, lessThan(0.02),
          reason: 'C* clamped to 0 → a neutral grey, chroma ≈ 0');
    });

    test('a near-black colour runs the CIELAB linear-segment path', () {
      const black = ColourValue(
        srgb: (r: 0.02, g: 0.02, b: 0.02),
        xyz: (x: 0.005, y: 0.005, z: 0.005),
        oklch: (l: 0.1, c: 0.0, h: 0.0),
      );
      final dried = driedColour(
          black, const WetDryTransform(lightnessDelta: -1, hueDeltaDeg: 5));
      // Stays dark and non-negative — the f()/fInv() linear branches are sound.
      expect(dried.xyz.y, inInclusiveRange(0.0, 0.02));
    });
  });

  group('toDryState', () {
    test('the identity transform returns the recipe unchanged', () {
      final recipe = recipeWith(wet);
      expect(toDryState(recipe, WetDryTransform.none), same(recipe));
    });

    test('re-renders the colour but carries every other field through', () {
      final recipe = recipeWith(wet);
      final dry = toDryState(recipe,
          const WetDryTransform(lightnessDelta: -3, hueDeltaDeg: 3));
      // The toggle is a state transform, not a re-solve.
      expect(dry.parts, recipe.parts);
      expect(dry.deltaE00, recipe.deltaE00);
      expect(dry.provenance, recipe.provenance);
      expect(dry.outOfGamut, recipe.outOfGamut);
      expect(dry.verdict, recipe.verdict);
      expect(dry.medium, recipe.medium);
      // Only the colour moves, and it moves darker.
      expect(dry.colour, isNot(recipe.colour));
      expect(dry.colour.xyz.y, lessThan(recipe.colour.xyz.y));
    });
  });
}
