import 'package:pigment_km/pigment_km.dart';
import 'package:pigment_km/src/colour/oklch.dart';
import 'package:test/test.dart';

// Hide the reference's OKLCh→linear inverse so the unit test exercises the
// library's own (`oklch.dart`); the reference's `srgbToOklch`/`hueDiffDeg`/
// `colourFromSrgb` are the independent yardstick.
import 'acceptance/harness/colour_math.dart' hide oklchToLinearSrgb;

/// Unit tests for the COLOR-3 OKLCh gamut mapper (AC-2) and the shared
/// `oklch.dart` conversion primitives.
///
/// Cross-checked against the acceptance suite's *independent* colour reference
/// ([srgbToOklch], [hueDiffDeg]) so the mapped result is measured against a
/// trusted OKLCh, not the library's own.
void main() {
  bool outside01(double v) => v < 0.0 || v > 1.0;

  group('gamutMap', () {
    test('an out-of-gamut colour is brought into gamut with hue and lightness '
        'preserved and chroma reduced', () {
      // A vivid green beyond sRGB: its OKLCh chroma exceeds what sRGB can show
      // at this lightness and hue, so the raw sRGB encoding is out of range.
      const outOfGamut = ColourValue(
        srgb: (r: -0.22, g: 1.09, b: -0.07),
        xyz: (x: 0.28, y: 0.52, z: 0.10),
        oklch: (l: 0.78, c: 0.37, h: 149.0),
      );

      final mapped = gamutMap(outOfGamut);

      // Every channel now sits inside the gamut.
      expect(mapped.srgb.r, inInclusiveRange(0.0, 1.0));
      expect(mapped.srgb.g, inInclusiveRange(0.0, 1.0));
      expect(mapped.srgb.b, inInclusiveRange(0.0, 1.0));

      // Lightness and hue are held fixed; chroma is reduced to reach the gamut.
      expect(mapped.oklch.l, closeTo(outOfGamut.oklch.l, 1e-9),
          reason: 'lightness is held fixed by construction');
      expect(mapped.oklch.h, closeTo(outOfGamut.oklch.h, 1e-9),
          reason: 'hue is held fixed by construction');
      expect(mapped.oklch.c, lessThan(outOfGamut.oklch.c));
      expect(mapped.oklch.c, greaterThan(0.0),
          reason: 'it should keep as much chroma as the gamut allows');

      // The reported OKLCh is *genuinely* in gamut: its UNCLAMPED linear sRGB
      // already lies in [0,1], so no channel is hidden by the encoder's clamp.
      // Rejects a mapper that stops above the boundary (reports reduced chroma
      // but still out of gamut, leaning on encodeGamma to clip a channel).
      final reportedLinear = oklchToLinearSrgb(mapped.oklch);
      expect(reportedLinear.r, inInclusiveRange(-1e-6, 1 + 1e-6));
      expect(reportedLinear.g, inInclusiveRange(-1e-6, 1 + 1e-6));
      expect(reportedLinear.b, inInclusiveRange(-1e-6, 1 + 1e-6));

      // The re-encoded sRGB, read back through the independent reference, still
      // carries the fixed hue and lightness — the triple is consistent.
      final ref = srgbToOklch(mapped.srgb);
      expect(ref.l, closeTo(outOfGamut.oklch.l, 0.02),
          reason: 'lightness preserved end to end');
      expect(hueDiffDeg(ref.h, outOfGamut.oklch.h), lessThan(2.0),
          reason: 'hue preserved end to end');

      // It must land essentially on the gamut boundary, not well inside it: a
      // nudge more chroma would push a channel back out of range.
      final justBeyond = oklchToLinearSrgb(
          (l: mapped.oklch.l, c: mapped.oklch.c + 1e-3, h: mapped.oklch.h));
      expect(
        outside01(justBeyond.r) ||
            outside01(justBeyond.g) ||
            outside01(justBeyond.b),
        isTrue,
        reason: 'the result sits at the gamut boundary (max retained chroma)',
      );

      // Rejects the naive per-channel clamp: clamping (-0.22, 1.09, -0.07) would
      // pin to (0, 1, 0) and shift the hue; the mapped colour is not that.
      final clamped = (
        r: outOfGamut.srgb.r.clamp(0.0, 1.0),
        g: outOfGamut.srgb.g.clamp(0.0, 1.0),
        b: outOfGamut.srgb.b.clamp(0.0, 1.0),
      );
      expect(
        (mapped.srgb.r - clamped.r).abs() < 1e-6 &&
            (mapped.srgb.g - clamped.g).abs() < 1e-6 &&
            (mapped.srgb.b - clamped.b).abs() < 1e-6,
        isFalse,
        reason: 'gamut mapping is not a hard per-channel clip',
      );
    });

    test('an in-gamut colour is returned unchanged', () {
      // A plainly displayable mid colour — its OKLCh encodes inside sRGB.
      const srgb = (r: 0.40, g: 0.55, b: 0.30);
      final inGamut = colourFromSrgb(srgb);

      final mapped = gamutMap(inGamut);

      expect(identical(mapped, inGamut), isTrue,
          reason: 'an in-gamut colour is passed through unchanged');
    });
  });

  group('oklch conversion primitives', () {
    test('OKLCh ↔ linear sRGB round-trips for an in-gamut colour', () {
      // Forward then inverse returns the starting linear sRGB.
      const linear = (r: 0.3, g: 0.6, b: 0.45);
      final oklch = linearSrgbToOklch(linear);
      final back = oklchToLinearSrgb(oklch);
      expect(back.r, closeTo(linear.r, 1e-6));
      expect(back.g, closeTo(linear.g, 1e-6));
      expect(back.b, closeTo(linear.b, 1e-6));
    });

    test('XYZ ↔ linear sRGB round-trips', () {
      const linear = (r: 0.2, g: 0.5, b: 0.7);
      final xyz = linearSrgbToXyz(linear);
      final back = xyzToLinearSrgb(xyz);
      expect(back.r, closeTo(linear.r, 1e-6));
      expect(back.g, closeTo(linear.g, 1e-6));
      expect(back.b, closeTo(linear.b, 1e-6));
    });
  });
}
