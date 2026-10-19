import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

/// Unit tests for the multi-illuminant metamerism index (STRETCH-3, AC-27,
/// design §9): `assessMetamerism` over the public surface.
///
/// The illuminant SPDs mirror the acceptance fixture's Planckian placeholders
/// (daylight D65 ≈ 6500 K, a warm studio light ≈ 2856 K), computed from Planck's
/// law and normalized to 1.0 at 560 nm.
void main() {
  final d65 = _planckianSpd(6500);
  final warm = _planckianSpd(2856);

  group('assessMetamerism', () {
    test('a spectral (non-metameric) match scores index 0 under any pair', () {
      final target = _flat(0.5);
      final a = assessMetamerism(
        target: target,
        candidate: target,
        referenceIlluminant: d65,
        testIlluminant: warm,
      );
      expect(a.deltaE00Reference, closeTo(0.0, 1e-9));
      expect(a.deltaE00Test, closeTo(0.0, 1e-9));
      expect(a.index, closeTo(0.0, 1e-9));
      expect(a.illuminantFragile, isFalse);
    });

    test('a metameric black (equal under D65) degrades under the warm light, '
        'scoring a positive index and a fragile flag', () {
      final target = _flat(0.5);
      final candidate = Float32List(CanonicalGrid.bins);
      final delta = _metamericBlack(
          List<double>.generate(CanonicalGrid.bins, (i) => math.sin(i * 0.9) * 0.45));
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        candidate[i] = target[i] + delta[i];
      }

      final m = assessMetamerism(
        target: target,
        candidate: candidate,
        referenceIlluminant: d65,
        testIlluminant: warm,
      );
      // Matches under D65 to machine precision (the metameric black leaves D65
      // tristimulus unchanged) …
      expect(m.deltaE00Reference, lessThan(1e-3));
      // … but genuinely diverges under the warm light …
      expect(m.deltaE00Test, greaterThan(1.0));
      // … so the index is that degradation and the match is flagged fragile.
      expect(m.index, closeTo(m.deltaE00Test - m.deltaE00Reference, 1e-9));
      expect(m.index, greaterThan(defaultMetamerismFragileThreshold));
      expect(m.illuminantFragile, isTrue);
    });

    test('the index requires the test illuminant: test == reference yields 0',
        () {
      final target = _flat(0.5);
      final candidate = Float32List(CanonicalGrid.bins);
      final delta = _metamericBlack(
          List<double>.generate(CanonicalGrid.bins, (i) => math.sin(i * 0.9) * 0.45));
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        candidate[i] = target[i] + delta[i];
      }
      final m = assessMetamerism(
        target: target,
        candidate: candidate,
        referenceIlluminant: d65,
        testIlluminant: d65,
      );
      expect(m.index, lessThan(1e-6));
      expect(m.illuminantFragile, isFalse);
    });

    test('a poor but illuminant-stable match scores ~0 and is not fragile '
        '(the index is degradation, not absolute test-light error)', () {
      final target = _flat(0.5);
      // Same spectral shape, uniformly darker: a bad match under D65, but its
      // mismatch does not grow under the warm light (no metamerism).
      final stable = _flat(0.35);
      final m = assessMetamerism(
        target: target,
        candidate: stable,
        referenceIlluminant: d65,
        testIlluminant: warm,
      );
      expect(m.deltaE00Reference, greaterThan(5.0));
      // A test-only index (= deltaE00Test) would exceed the threshold here …
      expect(m.deltaE00Test, greaterThan(defaultMetamerismFragileThreshold));
      // … but the true degradation is ~0, so the match is not flagged fragile.
      expect(m.index, lessThan(defaultMetamerismFragileThreshold));
      expect(m.illuminantFragile, isFalse);
    });

    test('a degrading recipe gets a higher index than a robust one', () {
      final target = _flat(0.5);
      final robust = assessMetamerism(
        target: target,
        candidate: target,
        referenceIlluminant: d65,
        testIlluminant: warm,
      );
      final fragileSpec = Float32List(CanonicalGrid.bins);
      final delta = _metamericBlack(
          List<double>.generate(CanonicalGrid.bins, (i) => math.sin(i * 0.9) * 0.45));
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        fragileSpec[i] = target[i] + delta[i];
      }
      final fragile = assessMetamerism(
        target: target,
        candidate: fragileSpec,
        referenceIlluminant: d65,
        testIlluminant: warm,
      );
      expect(fragile.index, greaterThan(robust.index));
    });

    test('the fragility threshold is honoured', () {
      final target = _flat(0.5);
      final candidate = Float32List(CanonicalGrid.bins);
      final delta = _metamericBlack(
          List<double>.generate(CanonicalGrid.bins, (i) => math.sin(i * 0.9) * 0.45));
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        candidate[i] = target[i] + delta[i];
      }
      // A huge threshold leaves even a real degradation un-flagged …
      final lenient = assessMetamerism(
        target: target,
        candidate: candidate,
        referenceIlluminant: d65,
        testIlluminant: warm,
        fragileThreshold: 100.0,
      );
      expect(lenient.index, greaterThan(0.0));
      expect(lenient.illuminantFragile, isFalse);
      // … a zero threshold flags any positive degradation.
      final strict = assessMetamerism(
        target: target,
        candidate: candidate,
        referenceIlluminant: d65,
        testIlluminant: warm,
        fragileThreshold: 0.0,
      );
      expect(strict.illuminantFragile, isTrue);
    });

    test('a very dark target exercises the low-tristimulus CIELAB branch', () {
      // Tristimulus ratio below (6/29)³ takes the linear CIELAB segment; a near
      // black reflectance drives it there. The assessment must still be finite.
      final target = _flat(0.002);
      final candidate = _flat(0.004);
      final m = assessMetamerism(
        target: target,
        candidate: candidate,
        referenceIlluminant: d65,
        testIlluminant: warm,
      );
      expect(m.deltaE00Reference.isFinite, isTrue);
      expect(m.deltaE00Test.isFinite, isTrue);
      expect(m.index, greaterThanOrEqualTo(0.0));
    });

    group('argument validation', () {
      final good = _flat(0.5);
      test('rejects an off-grid target', () {
        expect(
          () => assessMetamerism(
            target: Float32List(CanonicalGrid.bins - 1),
            candidate: good,
            referenceIlluminant: d65,
            testIlluminant: warm,
          ),
          throwsArgumentError,
        );
      });
      test('rejects an off-grid candidate', () {
        expect(
          () => assessMetamerism(
            target: good,
            candidate: Float32List(CanonicalGrid.bins + 1),
            referenceIlluminant: d65,
            testIlluminant: warm,
          ),
          throwsArgumentError,
        );
      });
      test('rejects an off-grid reference illuminant', () {
        expect(
          () => assessMetamerism(
            target: good,
            candidate: good,
            referenceIlluminant: Float32List(1),
            testIlluminant: warm,
          ),
          throwsArgumentError,
        );
      });
      test('rejects an off-grid test illuminant', () {
        expect(
          () => assessMetamerism(
            target: good,
            candidate: good,
            referenceIlluminant: d65,
            testIlluminant: Float32List(1),
          ),
          throwsArgumentError,
        );
      });
      test('rejects a non-positive reference illuminant sample', () {
        final bad = _flat(1.0)..[5] = 0.0;
        expect(
          () => assessMetamerism(
            target: good,
            candidate: good,
            referenceIlluminant: bad,
            testIlluminant: warm,
          ),
          throwsArgumentError,
        );
      });
      test('rejects a non-finite test illuminant sample', () {
        final bad = _flat(1.0)..[5] = double.nan;
        expect(
          () => assessMetamerism(
            target: good,
            candidate: good,
            referenceIlluminant: d65,
            testIlluminant: bad,
          ),
          throwsArgumentError,
        );
      });
      test('rejects a negative fragility threshold', () {
        expect(
          () => assessMetamerism(
            target: good,
            candidate: good,
            referenceIlluminant: d65,
            testIlluminant: warm,
            fragileThreshold: -1.0,
          ),
          throwsArgumentError,
        );
      });
      test('rejects a non-finite fragility threshold', () {
        expect(
          () => assessMetamerism(
            target: good,
            candidate: good,
            referenceIlluminant: d65,
            testIlluminant: warm,
            fragileThreshold: double.infinity,
          ),
          throwsArgumentError,
        );
      });
    });
  });
}

/// A flat reflectance/SPD at [value] across the canonical grid.
Float32List _flat(double value) =>
    Float32List.fromList(List<double>.filled(CanonicalGrid.bins, value));

/// Planck's-law relative SPD at [cctKelvin] on the canonical grid, normalized to
/// 1.0 at 560 nm — the acceptance fixture's placeholder illuminant model.
Float32List _planckianSpd(double cctKelvin) {
  const h = 6.62607015e-34;
  const c = 2.99792458e8;
  const kB = 1.380649e-23;
  double radiance(double nm) {
    final l = nm * 1e-9;
    final l5 = math.pow(l, 5).toDouble();
    return 1.0 / (l5 * (math.exp(h * c / (l * kB * cctKelvin)) - 1.0));
  }

  final ref = radiance(560);
  final out = Float32List(CanonicalGrid.bins);
  for (var i = 0; i < CanonicalGrid.bins; i++) {
    out[i] = radiance(CanonicalGrid.wavelengthAt(i)) / ref;
  }
  return out;
}

/// The metameric-black component of [seed] (see the AC-27 acceptance test): the
/// part orthogonal to the three D65 XYZ weight rows, recovered via the public
/// `spectrumToColour` on impulse spectra. Adding it leaves D65 tristimulus fixed.
List<double> _metamericBlack(List<double> seed) {
  const n = CanonicalGrid.bins;
  final rows = <List<double>>[
    List<double>.filled(n, 0),
    List<double>.filled(n, 0),
    List<double>.filled(n, 0),
  ];
  for (var i = 0; i < n; i++) {
    final e = Float32List(n);
    e[i] = 1.0;
    final xyz = spectrumToColour(e).xyz;
    rows[0][i] = xyz.x;
    rows[1][i] = xyz.y;
    rows[2][i] = xyz.z;
  }
  double dot(List<double> a, List<double> b) {
    var s = 0.0;
    for (var i = 0; i < n; i++) {
      s += a[i] * b[i];
    }
    return s;
  }

  final basis = <List<double>>[];
  for (final row in rows) {
    final v = List<double>.from(row);
    for (final b in basis) {
      final p = dot(v, b);
      for (var i = 0; i < n; i++) {
        v[i] -= p * b[i];
      }
    }
    final norm = math.sqrt(dot(v, v));
    for (var i = 0; i < n; i++) {
      v[i] /= norm;
    }
    basis.add(v);
  }
  final delta = List<double>.from(seed);
  for (final b in basis) {
    final p = dot(delta, b);
    for (var i = 0; i < n; i++) {
      delta[i] -= p * b[i];
    }
  }
  return delta;
}
