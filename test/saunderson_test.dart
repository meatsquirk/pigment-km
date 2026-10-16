import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

/// Unit tests for the KM-3 Saunderson surface correction (AC-4):
/// [configForMedium] (per-medium `k1,k2`), [saundersonToMeasured]
/// (`R_m = k1 + (1−k1)(1−k2)R_i/(1−k2·R_i)`) and its inverse
/// [saundersonToInternal].
///
/// The anchor points are computed by hand, independently of the production
/// formula, so a self-consistent round-trip cannot hide a wrong forward model;
/// the per-medium control rejects a single global `k1,k2`, and the not-a-no-op
/// control rejects an identity "correction".
void main() {
  Spectrum spectrumOf(List<double> xs) => Float32List.fromList(xs);

  // A sweep of internal reflectances spanning dark to light (all in (0,1)).
  final sweep = <double>[0.05, 0.2, 0.35, 0.5, 0.65, 0.8, 0.95];

  group('configForMedium', () {
    test('acrylic carries its documented defaults (k1≈0.04, k2≈0.6)', () {
      final acrylic = configForMedium(Medium.acrylic);
      expect(acrylic.medium, Medium.acrylic);
      expect(acrylic.k1, closeTo(0.04, 1e-12));
      expect(acrylic.k2, closeTo(0.6, 1e-12));
      // The drying transform defaults to the identity until TUNE sets it.
      expect(acrylic.wetDry, WetDryTransform.none);
    });

    test('oil carries its own distinct defaults', () {
      final oil = configForMedium(Medium.oil);
      expect(oil.medium, Medium.oil);
      expect(oil.k1, closeTo(0.05, 1e-12));
      expect(oil.k2, closeTo(0.6, 1e-12));
    });

    test('acrylic and oil do not share both constants', () {
      final acrylic = configForMedium(Medium.acrylic);
      final oil = configForMedium(Medium.oil);
      expect(acrylic.k1 != oil.k1 || acrylic.k2 != oil.k2, isTrue);
    });
  });

  group('saundersonToMeasured', () {
    test('output has one sample per input sample', () {
      final out = saundersonToMeasured(spectrumOf(sweep), configForMedium(Medium.acrylic));
      expect(out, hasLength(sweep.length));
    });

    test('matches the hand-computed value at R_i=0.5 (acrylic)', () {
      // k1=0.04, k2=0.6 → a=(0.96)(0.4)=0.384;
      // R_m = 0.04 + 0.384·0.5/(1−0.3) = 0.04 + 0.192/0.7 = 0.3142857…
      final out = saundersonToMeasured(
          spectrumOf(const [0.5]), configForMedium(Medium.acrylic));
      expect(out.single, closeTo(0.31428571, 1e-6));
    });

    test('matches the hand-computed value at R_i=0.5 (oil)', () {
      // k1=0.05, k2=0.6 → a=(0.95)(0.4)=0.38;
      // R_m = 0.05 + 0.38·0.5/0.7 = 0.05 + 0.19/0.7 = 0.3214286…
      final out = saundersonToMeasured(
          spectrumOf(const [0.5]), configForMedium(Medium.oil));
      expect(out.single, closeTo(0.32142857, 1e-6));
    });

    test('adds surface reflection — measured differs from internal (not a no-op)',
        () {
      final internal = spectrumOf(sweep);
      final measured = saundersonToMeasured(internal, configForMedium(Medium.acrylic));
      var anyDifferent = false;
      for (var i = 0; i < sweep.length; i++) {
        if ((measured[i] - internal[i]).abs() > 1e-4) anyDifferent = true;
      }
      expect(anyDifferent, isTrue,
          reason: 'a k1>0 correction must shift the reflectance');
    });

    test('the same internal input corrects differently per medium (control)', () {
      final internal = spectrumOf(sweep);
      final acrylic = saundersonToMeasured(internal, configForMedium(Medium.acrylic));
      final oil = saundersonToMeasured(internal, configForMedium(Medium.oil));
      expect(spectraEqual(acrylic, oil), isFalse,
          reason: 'distinct per-medium k1,k2 must produce distinct measured R');
    });
  });

  group('saundersonToInternal', () {
    test('output has one sample per input sample', () {
      final out = saundersonToInternal(spectrumOf(sweep), configForMedium(Medium.oil));
      expect(out, hasLength(sweep.length));
    });

    test('recovers the hand-computed internal at R_m=0.31428571 (acrylic)', () {
      final out = saundersonToInternal(
          spectrumOf(const [0.31428571]), configForMedium(Medium.acrylic));
      expect(out.single, closeTo(0.5, 1e-6));
    });
  });

  group('round-trip', () {
    for (final medium in Medium.values) {
      test('internal → measured → internal recovers the original ($medium)', () {
        final config = configForMedium(medium);
        final internal = spectrumOf(sweep);
        final measured = saundersonToMeasured(internal, config);
        final recovered = saundersonToInternal(measured, config);
        for (var i = 0; i < sweep.length; i++) {
          expect(recovered[i], closeTo(internal[i], 1e-6),
              reason: 'internal reflectance must round-trip at bin $i ($medium)');
        }
      });
    }
  });
}
