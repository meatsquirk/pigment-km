import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';
import 'package:pigment_km/src/colour/cmf_d65_weights.dart';
import 'package:test/test.dart';

import 'acceptance/harness/colour_math.dart';

/// Unit tests for the COLOR-2 spectrum→colour backend (AC-1): the precomputed
/// CMF·D65 weight vectors and [spectrumToColour].
///
/// Cross-checked against the acceptance suite's *independent* colour reference
/// ([srgbToXyz], [srgbToOklch], [deltaE00]) so a wrong transfer matrix or gamma
/// curve is rejected, not merely a wrong self-consistent one.
void main() {
  Spectrum flat(double r) =>
      Float32List.fromList(List<double>.filled(CanonicalGrid.bins, r));

  /// The full-range CIE D65/10° white point (what a perfect diffuser
  /// approximates — G-9/D-14, the observer the colour pipeline now uses).
  const canonicalD65 = (x: 0.94811, y: 1.0, z: 1.07304);

  group('cmf_d65_weights (precomputed CMF·D65)', () {
    test('each weight vector has exactly one sample per canonical bin', () {
      expect(xBarD65, hasLength(CanonicalGrid.bins));
      expect(yBarD65, hasLength(CanonicalGrid.bins));
      expect(zBarD65, hasLength(CanonicalGrid.bins));
    });

    test('yBarD65Sum is the sum of yBarD65 (the luminance normalizer)', () {
      final sum = yBarD65.reduce((a, b) => a + b);
      expect(yBarD65Sum, closeTo(sum, 1e-6));
    });

    test('the normalized weight totals give the 400–700 nm D65 white point', () {
      // Σw / yBarD65Sum is the perfect-diffuser tristimulus: Y is exactly 1, and
      // X,Z land on the range-truncated D65 white — within ΔE00 1 of canonical.
      final x = xBarD65.reduce((a, b) => a + b) / yBarD65Sum;
      final y = yBarD65.reduce((a, b) => a + b) / yBarD65Sum;
      final z = zBarD65.reduce((a, b) => a + b) / yBarD65Sum;
      expect(y, closeTo(1.0, 1e-9));
      expect(deltaE00((x: x, y: y, z: z), canonicalD65), lessThan(1.0));
    });
  });

  group('spectrumToColour', () {
    test('a perfect diffuser maps to the D65 white point (AC-1 core)', () {
      final c = spectrumToColour(flat(1.0));
      expect(c.xyz.y, closeTo(1.0, 1e-9));
      expect(deltaE00(c.xyz, canonicalD65), lessThanOrEqualTo(1.0));
      expect(c.srgb.r, closeTo(1.0, 0.01));
      expect(c.srgb.g, closeTo(1.0, 0.01));
      expect(c.srgb.b, closeTo(1.0, 0.01));
      // A near-neutral white: chroma is tiny.
      expect(c.oklch.c, lessThan(0.02));
    });

    test('a black spectrum maps to black (covers the linear gamma segment)', () {
      final c = spectrumToColour(flat(0.0));
      expect(c.xyz, (x: 0.0, y: 0.0, z: 0.0));
      // Linear 0 ≤ 0.0031308 → the 12.92·v segment of the transfer function.
      expect(c.srgb.r, 0.0);
      expect(c.srgb.g, 0.0);
      expect(c.srgb.b, 0.0);
      expect(c.oklch.l, closeTo(0.0, 1e-9));
      expect(c.oklch.c, closeTo(0.0, 1e-9));
    });

    test('a mid grey round-trips through the independent sRGB reference', () {
      // In-gamut neutral: no channel is clamped, so the library's own XYZ and
      // OKLCh must agree with the reference recomputed from its sRGB — this
      // rejects a wrong XYZ→sRGB matrix or gamma curve.
      final c = spectrumToColour(flat(0.18));
      expect(deltaE00(c.xyz, srgbToXyz(c.srgb)), lessThan(0.5));
      final ref = srgbToOklch(c.srgb);
      expect(c.oklch.l, closeTo(ref.l, 5e-3));
      expect(c.oklch.c, closeTo(ref.c, 5e-3));
    });

    test('a short-wavelength spectrum is blue (covers the hue wrap branch)', () {
      // Reflectance only in 400–480 nm → a blue whose OKLab b is negative, so
      // atan2 returns a negative angle and the hue wraps by +360.
      final blue = Float32List(CanonicalGrid.bins);
      for (var i = 0; i <= 8; i++) {
        blue[i] = 1.0;
      }
      final c = spectrumToColour(blue);
      expect(c.srgb.b, greaterThan(c.srgb.r));
      expect(c.srgb.b, greaterThan(c.srgb.g));
      expect(c.oklch.c, greaterThan(0.05));
      expect(c.oklch.h, inInclusiveRange(180.0, 320.0),
          reason: 'blue hue after the +360 wrap');
    });

    test('rejects a spectrum off the canonical grid', () {
      expect(
        () => spectrumToColour(Float32List.fromList(const [0.1, 0.2, 0.3])),
        throwsArgumentError,
      );
    });
  });
}
