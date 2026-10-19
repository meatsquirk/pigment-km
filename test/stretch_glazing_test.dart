import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

/// Unit tests for the finite-thickness Kubelka–Munk layering equation
/// ([glazedReflectance], design §3.4; AC-26 / STRETCH-2).
///
/// The physical controls (opaque limit, vanishing limit, self-consistency) are
/// verified independently of the implementation; the general case is checked
/// against hand-computed closed-form values.

Spectrum _flat(double v) =>
    Float32List.fromList(List<double>.filled(CanonicalGrid.bins, v));

KmMix _glaze({required double k, required double s}) => (k: _flat(k), s: _flat(s));

void main() {
  group('glazedReflectance — finite-thickness KM layering (§3.4)', () {
    test('general case matches the hand-computed closed form', () {
      // K/S = 0.5, S = 1, ground 0.8, thickness 0.5.
      //   a = 1.5, b = sqrt(1.25) = 1.1180339887, y = b·S·X = 0.559017,
      //   b·coth(y) = 2.204058, R = (1 − 0.8·(a − bCoth)) / (a − 0.8 + bCoth)
      //            = 1.563248 / 2.904058 = 0.538298.
      final r = glazedReflectance(
        glaze: _glaze(k: 0.5, s: 1.0),
        thickness: 0.5,
        ground: _flat(0.8),
      );
      for (final v in r) {
        expect(v, closeTo(0.538298, 1e-5));
      }
    });

    test('opaque limit: a thick glaze reproduces the opaque body reflectance '
        'and ignores the ground (control)', () {
      final glaze = _glaze(k: 0.5, s: 1.0);
      final opaque = kmReflectance(Float32List.fromList(
          List<double>.filled(CanonicalGrid.bins, 0.5))); // K/S = 0.5
      // Two very different grounds — a thick glaze must give the same opaque R.
      final overWhite = glazedReflectance(
          glaze: glaze, thickness: 1e6, ground: _flat(0.95));
      final overBlack = glazedReflectance(
          glaze: glaze, thickness: 1e6, ground: _flat(0.02));
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        expect(overWhite[i], closeTo(opaque[i], 1e-6));
        expect(overBlack[i], closeTo(opaque[i], 1e-6));
      }
    });

    test('vanishing limit: an infinitely thin film is the bare ground', () {
      final r = glazedReflectance(
        glaze: _glaze(k: 0.5, s: 1.0),
        thickness: 1e-6,
        ground: _flat(0.3),
      );
      for (final v in r) {
        expect(v, closeTo(0.3, 1e-3));
      }
    });

    test('self-consistency: a glaze over a ground of its own opaque colour '
        'changes nothing at any thickness', () {
      final rInf = kmReflectance(Float32List.fromList(
          List<double>.filled(CanonicalGrid.bins, 0.5)))[0]; // ≈ 0.381966
      for (final x in <double>[0.1, 0.7, 5.0]) {
        final r = glazedReflectance(
          glaze: _glaze(k: 0.5, s: 1.0),
          thickness: x,
          ground: _flat(rInf),
        );
        for (final v in r) {
          expect(v, closeTo(rInf, 1e-5),
              reason: 'should equal the opaque reflectance at thickness $x');
        }
      }
    });

    test('a finite glaze lies strictly between the ground and the opaque form '
        '(reusing the opaque form would ignore the ground)', () {
      final rInf = kmReflectance(Float32List.fromList(
          List<double>.filled(CanonicalGrid.bins, 0.5)))[0]; // ≈ 0.382
      const rg = 0.8;
      final r = glazedReflectance(
        glaze: _glaze(k: 0.5, s: 1.0),
        thickness: 0.5,
        ground: _flat(rg),
      );
      for (final v in r) {
        expect(v, greaterThan(rInf));
        expect(v, lessThan(rg));
      }
    });

    test('non-absorbing (K = 0) scattering film uses the finite 1/(S·X) limit', () {
      // K/S = 0 → a = 1, b = 0 → b·coth(b·S·X) → 1/(S·X) = 1/2 at X = 2, S = 1.
      //   R = (1 − 0.5·(1 − 0.5)) / (1 − 0.5 + 0.5) = 0.75.
      final r = glazedReflectance(
        glaze: _glaze(k: 0.0, s: 1.0),
        thickness: 2.0,
        ground: _flat(0.5),
      );
      for (final v in r) {
        expect(v, closeTo(0.75, 1e-6));
      }
    });

    group('input validation', () {
      final glaze = _glaze(k: 0.5, s: 1.0);
      final ground = _flat(0.5);

      test('rejects a zero thickness', () {
        expect(
            () => glazedReflectance(glaze: glaze, thickness: 0, ground: ground),
            throwsArgumentError);
      });
      test('rejects a negative thickness', () {
        expect(
            () => glazedReflectance(glaze: glaze, thickness: -1, ground: ground),
            throwsArgumentError);
      });
      test('rejects a non-finite thickness', () {
        expect(
            () => glazedReflectance(
                glaze: glaze, thickness: double.infinity, ground: ground),
            throwsArgumentError);
        expect(
            () => glazedReflectance(
                glaze: glaze, thickness: double.nan, ground: ground),
            throwsArgumentError);
      });
      test('rejects an off-grid glaze K spectrum', () {
        expect(
            () => glazedReflectance(
                glaze: (k: Float32List(3), s: _flat(1.0)),
                thickness: 1.0,
                ground: ground),
            throwsArgumentError);
      });
      test('rejects an off-grid glaze S spectrum', () {
        expect(
            () => glazedReflectance(
                glaze: (k: _flat(0.5), s: Float32List(3)),
                thickness: 1.0,
                ground: ground),
            throwsArgumentError);
      });
      test('rejects an off-grid ground spectrum', () {
        expect(
            () => glazedReflectance(
                glaze: glaze, thickness: 1.0, ground: Float32List(3)),
            throwsArgumentError);
      });
    });
  });
}
