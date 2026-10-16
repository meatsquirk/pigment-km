import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

/// Unit tests for the KM-4 two-constant mixing primitive (the mechanism AC-5
/// needs): [mixTwoConstant], the elementwise volume-weighted sums
/// `Kmix = Σ v_i·K_i`, `Smix = Σ v_i·S_i` (design §3.3, §5).
///
/// The reference [_refMix] is computed independently of the production code in
/// plain doubles, so a shared slip can't hide behind a self-consistent property:
/// an engine that averaged instead of summing, normalised the weights, mixed
/// only the `K/S` ratio, or dropped `S` fails the per-wavelength checks.
typedef Paint = ({Spectrum k, Spectrum s});

void main() {
  const bins = CanonicalGrid.bins;

  /// Builds a 31-bin spectrum from a per-bin generator.
  Spectrum spec(double Function(int) f) {
    final out = Float32List(bins);
    for (var i = 0; i < bins; i++) {
      out[i] = f(i);
    }
    return out;
  }

  /// Independent reference: elementwise Σ weight·K and Σ weight·S in doubles.
  ({List<double> k, List<double> s}) refMix(List<MixComponent> cs) {
    final k = List<double>.filled(bins, 0);
    final s = List<double>.filled(bins, 0);
    for (final c in cs) {
      for (var i = 0; i < bins; i++) {
        k[i] += c.weight * c.k[i];
        s[i] += c.weight * c.s[i];
      }
    }
    return (k: k, s: s);
  }

  // Two distinct paints with K and S that vary differently across the grid, so
  // that mixing K separately from S is observable (a ratio-only mix would not
  // reproduce both).
  final paintA = (
    k: spec((i) => 0.10 + 0.02 * i),
    s: spec((i) => 2.0 - 0.01 * i),
  );
  final paintB = (
    k: spec((i) => 1.50 - 0.03 * i),
    s: spec((i) => 0.30 + 0.04 * i),
  );

  MixComponent comp(Paint p, double w) => (k: p.k, s: p.s, weight: w);

  group('mixTwoConstant — shape', () {
    test('Kmix and Smix each have one sample per grid bin', () {
      final mix = mixTwoConstant([comp(paintA, 1.0)]);
      expect(mix.k, hasLength(bins));
      expect(mix.s, hasLength(bins));
    });
  });

  group('mixTwoConstant — weighted sum', () {
    test('matches the independent Σv·K / Σv·S reference at every wavelength', () {
      final cs = [comp(paintA, 0.3), comp(paintB, 0.7)];
      final mix = mixTwoConstant(cs);
      final ref = refMix(cs);
      for (var i = 0; i < bins; i++) {
        expect(mix.k[i], closeTo(ref.k[i], 1e-5),
            reason: 'Kmix mismatch at bin $i');
        expect(mix.s[i], closeTo(ref.s[i], 1e-5),
            reason: 'Smix mismatch at bin $i');
      }
    });

    test('a single paint at weight 1 is that paint unchanged', () {
      final mix = mixTwoConstant([comp(paintA, 1.0)]);
      for (var i = 0; i < bins; i++) {
        expect(mix.k[i], closeTo(paintA.k[i], 1e-5));
        expect(mix.s[i], closeTo(paintA.s[i], 1e-5));
      }
    });

    test('K and S are mixed independently (not via the K/S ratio alone)', () {
      // paintB has, at bin 0, a high K and low S; paintA the reverse. A mix
      // must track each sum on its own — reconstructing from a single mixed
      // ratio could not reproduce both Kmix and Smix here.
      final cs = [comp(paintA, 0.5), comp(paintB, 0.5)];
      final mix = mixTwoConstant(cs);
      final ref = refMix(cs);
      expect(mix.k[0], closeTo(ref.k[0], 1e-5));
      expect(mix.s[0], closeTo(ref.s[0], 1e-5));
      // Sanity: the two mixed channels are genuinely different numbers.
      expect((mix.k[0] - mix.s[0]).abs(), greaterThan(1e-3));
    });
  });

  group('mixTwoConstant — self-mix idempotence (AC-5)', () {
    test('mixing a paint with only itself reproduces it at any ratio', () {
      for (final split in const [
        [0.5, 0.5],
        [0.3, 0.7],
        [0.9, 0.1],
        [0.25, 0.75],
      ]) {
        final mix = mixTwoConstant(
          [comp(paintA, split[0]), comp(paintA, split[1])],
        );
        for (var i = 0; i < bins; i++) {
          expect(mix.k[i], closeTo(paintA.k[i], 1e-5),
              reason: 'Kmix ≠ pure at bin $i for split $split');
          expect(mix.s[i], closeTo(paintA.s[i], 1e-5),
              reason: 'Smix ≠ pure at bin $i for split $split');
        }
      }
    });

    test('splitting a paint into three parts summing to w equals weight w', () {
      final split = mixTwoConstant(
        [comp(paintA, 0.2), comp(paintA, 0.5), comp(paintA, 0.3)],
      );
      final whole = mixTwoConstant([comp(paintA, 1.0)]);
      for (var i = 0; i < bins; i++) {
        expect(split.k[i], closeTo(whole.k[i], 1e-5));
        expect(split.s[i], closeTo(whole.s[i], 1e-5));
      }
    });
  });

  group('mixTwoConstant — order independence (AC-5)', () {
    test('permuting the components does not change Kmix or Smix', () {
      final forward = [comp(paintA, 0.2), comp(paintB, 0.3), comp(paintA, 0.5)];
      final reversed = forward.reversed.toList();
      final a = mixTwoConstant(forward);
      final b = mixTwoConstant(reversed);
      for (var i = 0; i < bins; i++) {
        expect(a.k[i], closeTo(b.k[i], 1e-6),
            reason: 'Kmix changed under permutation at bin $i');
        expect(a.s[i], closeTo(b.s[i], 1e-6),
            reason: 'Smix changed under permutation at bin $i');
      }
    });
  });

  group('mixTwoConstant — weights used as given, not normalised', () {
    test('weights summing to 2 double the result (no internal normalisation)',
        () {
      final raw = mixTwoConstant([comp(paintA, 1.0), comp(paintA, 1.0)]);
      for (var i = 0; i < bins; i++) {
        expect(raw.k[i], closeTo(2 * paintA.k[i], 1e-5),
            reason: 'raw weights must not be normalised (K) at bin $i');
        expect(raw.s[i], closeTo(2 * paintA.s[i], 1e-5),
            reason: 'raw weights must not be normalised (S) at bin $i');
      }
    });

    test('a zero-weight component contributes nothing', () {
      final withZero =
          mixTwoConstant([comp(paintA, 1.0), comp(paintB, 0.0)]);
      for (var i = 0; i < bins; i++) {
        expect(withZero.k[i], closeTo(paintA.k[i], 1e-5));
        expect(withZero.s[i], closeTo(paintA.s[i], 1e-5));
      }
    });
  });

  group('mixTwoConstant — guards', () {
    test('an empty component list throws ArgumentError', () {
      expect(() => mixTwoConstant(const []), throwsArgumentError);
    });

    test('an off-grid spectrum throws ArgumentError', () {
      final shortK = Float32List(bins - 1);
      final goodS = Float32List(bins);
      expect(
        () => mixTwoConstant([(k: shortK, s: goodS, weight: 1.0)]),
        throwsArgumentError,
      );
    });
  });
}
