import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

/// Unit tests for the KM-2 Kubelka–Munk physics backend (AC-3): [kmReflectance]
/// (opaque `R∞ = 1 + x − √(x²+2x)`) and its inverse [kmFunction]
/// (`K/S = (1−R)²/(2R)`).
///
/// The analytic reference points and the independent closed form in [_rInfinity]
/// reject a wrong formula (not merely a self-consistent round-trip): an engine
/// that picked the `+√` root, dropped the `2x` term, or inverted the K–M
/// function wrongly fails these.
void main() {
  /// A reference implementation computed independently of the production code,
  /// so a shared algebra slip can't hide behind the round-trip.
  double rInfinity(double x) => 1 + x - math.sqrt(x * x + 2 * x);

  Spectrum spectrumOf(List<double> xs) => Float32List.fromList(xs);

  // A sweep of K/S ratios spanning strong reflectors (x≪1) to strong absorbers
  // (x≫1), plus the x=0 reference point.
  final sweep = <double>[0, 0.01, 0.1, 0.5, 1, 2, 5, 20, 100];

  group('kmReflectance', () {
    test('output has one sample per input sample', () {
      final out = kmReflectance(spectrumOf(sweep));
      expect(out, hasLength(sweep.length));
    });

    test('K/S = 0 (no absorption) gives R∞ = 1', () {
      final out = kmReflectance(Float32List(CanonicalGrid.bins));
      for (final v in out) {
        expect(v, closeTo(1.0, 1e-6));
      }
    });

    test('reflectance is physical in (0, 1] and uses the −√ (lower) root', () {
      final out = kmReflectance(spectrumOf(sweep));
      for (var i = 0; i < sweep.length; i++) {
        expect(out[i], inInclusiveRange(0.0, 1.0),
            reason: 'R∞ must be ≤ 1 — rejects the +√ branch at x=${sweep[i]}');
        expect(out[i], greaterThan(0.0),
            reason: 'R∞ > 0 for finite x at x=${sweep[i]}');
      }
    });

    test('matches the independent closed form at every sampled x', () {
      final out = kmReflectance(spectrumOf(sweep));
      for (var i = 0; i < sweep.length; i++) {
        expect(out[i], closeTo(rInfinity(sweep[i]), 1e-6),
            reason: 'R∞ formula mismatch at x=${sweep[i]}');
      }
    });

    test('x = 1 gives the analytic value 2 − √3', () {
      final out = kmReflectance(spectrumOf(const [1.0]));
      expect(out.single, closeTo(2 - math.sqrt(3), 1e-6));
    });

    test('is strictly decreasing in K/S (more absorption → less reflectance)',
        () {
      final out = kmReflectance(spectrumOf(sweep));
      for (var i = 1; i < sweep.length; i++) {
        expect(out[i], lessThan(out[i - 1]),
            reason: 'R∞ must fall as K/S rises (${sweep[i - 1]}→${sweep[i]})');
      }
    });
  });

  group('kmFunction', () {
    test('output has one sample per input sample', () {
      final out = kmFunction(spectrumOf(const [0.2, 0.5, 0.9]));
      expect(out, hasLength(3));
    });

    test('R = 1 (no absorption) gives K/S = 0', () {
      final out = kmFunction(spectrumOf(const [1.0]));
      expect(out.single, closeTo(0.0, 1e-9));
    });

    test('matches the closed form (1−R)²/(2R) at a known point', () {
      // R = 0.25 → (0.75²)/(0.5) = 0.5625/0.5 = 1.125.
      final out = kmFunction(spectrumOf(const [0.25]));
      expect(out.single, closeTo(1.125, 1e-9));
    });
  });

  group('round-trip', () {
    test('kmFunction ∘ kmReflectance recovers K/S across the sweep', () {
      final koverS = spectrumOf(sweep);
      final recovered = kmFunction(kmReflectance(koverS));
      expect(recovered, hasLength(sweep.length));
      for (var i = 0; i < sweep.length; i++) {
        // Float32 storage amplifies error ~1/(2R²) for strong absorbers
        // (R→0 as K/S→∞), so scale the tolerance with the value.
        final tol = math.max(1e-5, sweep[i] * 1e-4);
        expect(recovered[i], closeTo(sweep[i], tol),
            reason: 'K/S must round-trip at x=${sweep[i]}');
      }
    });
  });
}
