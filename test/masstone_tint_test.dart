import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

/// Unit coverage for `deriveKsFromMasstoneTint` (DATA-4, AC-10): the per-λ
/// least-squares recovery of two-constant K,S from a masstone + tint series,
/// plus its input validation and singular-series guard.
void main() {
  group('deriveKsFromMasstoneTint', () {
    final trueK = _bump(peakBin: 14, floor: 0.05, height: 0.9);
    final trueS = _flat(0.3);
    final whiteK = _flat(0.05);
    final whiteS = _flat(1.0); // S_w ≡ 1 (design §4.4).
    const fractions = <double>[0.25, 0.5, 0.75];

    List<Tint> buildTints() => [
          for (final c in fractions)
            (
              pigmentFraction: c,
              reflectance: _tintReflectance(c, trueK, trueS, whiteK, whiteS),
            ),
        ];
    Spectrum buildMasstone() =>
        _tintReflectance(1.0, trueK, trueS, whiteK, whiteS);

    test('recovers K,S that reproduce every tint and the masstone', () {
      final tints = buildTints();
      final masstone = buildMasstone();

      final derived = deriveKsFromMasstoneTint(
        masstone: masstone,
        tints: tints,
        whiteK: whiteK,
        whiteS: whiteS,
      );

      expect(derived.k, hasLength(CanonicalGrid.bins));
      expect(derived.s, hasLength(CanonicalGrid.bins));
      // Re-predict each tint (and the masstone) through the same opaque KM
      // reference the series was built from: the derived constants reproduce
      // them within tolerance.
      for (final t in tints) {
        final predicted = _tintReflectance(
            t.pigmentFraction, derived.k, derived.s, whiteK, whiteS);
        for (var i = 0; i < CanonicalGrid.bins; i++) {
          expect(predicted[i], closeTo(t.reflectance[i], 1e-3));
        }
      }
      final predictedMasstone =
          _tintReflectance(1.0, derived.k, derived.s, whiteK, whiteS);
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        expect(predictedMasstone[i], closeTo(masstone[i], 1e-3));
      }
    });

    test('recovers the true K,S (not merely their ratio)', () {
      final derived = deriveKsFromMasstoneTint(
        masstone: buildMasstone(),
        tints: buildTints(),
        whiteK: whiteK,
        whiteS: whiteS,
      );
      // A masstone-only fit would pin only K/S; the tint series separates them,
      // so the recovered constants match the true spectra closely.
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        expect(derived.k[i], closeTo(trueK[i], 1e-2));
        expect(derived.s[i], closeTo(trueS[i], 1e-2));
        expect(derived.k[i], greaterThanOrEqualTo(0.0));
        expect(derived.s[i], greaterThan(0.0));
      }
    });

    test('a measured reflectance of 0 stays finite (clamped before inversion)',
        () {
      final tints = <Tint>[
        (pigmentFraction: 0.5, reflectance: _flat(0.0)),
        (pigmentFraction: 0.25, reflectance: _flat(0.2)),
      ];
      final derived = deriveKsFromMasstoneTint(
        masstone: _flat(0.0),
        tints: tints,
        whiteK: whiteK,
        whiteS: whiteS,
      );
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        expect(derived.k[i].isFinite, isTrue);
        expect(derived.s[i].isFinite, isTrue);
      }
    });

    test('throws on an off-grid masstone', () {
      expect(
        () => deriveKsFromMasstoneTint(
          masstone: _flat(0.4, bins: CanonicalGrid.bins - 1),
          tints: buildTints(),
          whiteK: whiteK,
          whiteS: whiteS,
        ),
        throwsArgumentError,
      );
    });

    test('throws on an off-grid white or tint reflectance', () {
      expect(
        () => deriveKsFromMasstoneTint(
          masstone: buildMasstone(),
          tints: buildTints(),
          whiteK: _flat(0.05, bins: 2),
          whiteS: whiteS,
        ),
        throwsArgumentError,
      );
      expect(
        () => deriveKsFromMasstoneTint(
          masstone: buildMasstone(),
          tints: buildTints(),
          whiteK: whiteK,
          whiteS: _flat(1.0, bins: 2),
        ),
        throwsArgumentError,
      );
      expect(
        () => deriveKsFromMasstoneTint(
          masstone: buildMasstone(),
          tints: <Tint>[(pigmentFraction: 0.5, reflectance: _flat(0.4, bins: 3))],
          whiteK: whiteK,
          whiteS: whiteS,
        ),
        throwsArgumentError,
      );
    });

    test('throws when no tints are supplied', () {
      expect(
        () => deriveKsFromMasstoneTint(
          masstone: buildMasstone(),
          tints: const <Tint>[],
          whiteK: whiteK,
          whiteS: whiteS,
        ),
        throwsArgumentError,
      );
    });

    test('throws on a tint fraction outside (0, 1]', () {
      expect(
        () => deriveKsFromMasstoneTint(
          masstone: buildMasstone(),
          tints: <Tint>[(pigmentFraction: 1.5, reflectance: _flat(0.4))],
          whiteK: whiteK,
          whiteS: whiteS,
        ),
        throwsArgumentError,
      );
      expect(
        () => deriveKsFromMasstoneTint(
          masstone: buildMasstone(),
          tints: <Tint>[(pigmentFraction: 0.0, reflectance: _flat(0.4))],
          whiteK: whiteK,
          whiteS: whiteS,
        ),
        throwsArgumentError,
      );
    });

    test('throws when the series cannot separate K from S (singular)', () {
      // Every sample shares one flat reflectance → one K/S ratio across all
      // fractions, so the two unknowns are collinear and the normal matrix is
      // singular at every wavelength.
      expect(
        () => deriveKsFromMasstoneTint(
          masstone: _flat(0.4),
          tints: <Tint>[(pigmentFraction: 0.5, reflectance: _flat(0.4))],
          whiteK: _flat(0.1),
          whiteS: _flat(0.2),
        ),
        throwsStateError,
      );
    });
  });
}

/// A flat spectrum at [value] (length [bins], default the canonical grid).
Spectrum _flat(double value, {int bins = CanonicalGrid.bins}) =>
    Float32List.fromList(List<double>.filled(bins, value));

/// A smooth absorption bump: [floor] + [height]·gaussian peaking at [peakBin].
Spectrum _bump({
  required int peakBin,
  required double floor,
  required double height,
}) {
  final out = Float32List(CanonicalGrid.bins);
  for (var i = 0; i < CanonicalGrid.bins; i++) {
    final d = (i - peakBin) / 6.0;
    out[i] = floor + height * math.exp(-d * d);
  }
  return out;
}

/// An independent opaque two-constant KM reference (the same one AC-10 uses):
/// for a tint at pigment volume fraction [frac] of a pigment ([kPig],[sPig])
/// with a white ([kWhite],[sWhite]), the mix K,S are the volume-weighted sums
/// and `R∞ = 1 + x − √(x² + 2x)` for `x = Kmix/Smix`.
Spectrum _tintReflectance(
  double frac,
  Spectrum kPig,
  Spectrum sPig,
  Spectrum kWhite,
  Spectrum sWhite,
) {
  final out = Float32List(CanonicalGrid.bins);
  for (var i = 0; i < CanonicalGrid.bins; i++) {
    final k = frac * kPig[i] + (1 - frac) * kWhite[i];
    final s = frac * sPig[i] + (1 - frac) * sWhite[i];
    final x = k / s;
    out[i] = 1 + x - math.sqrt(x * x + 2 * x);
  }
  return out;
}
