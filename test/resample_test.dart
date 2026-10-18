import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

/// Unit coverage for `resampleOntoCanonical` (DATA-2, AC-8): every branch of the
/// linear resampler — validation, interior interpolation, endpoint clamp.
void main() {
  group('resampleOntoCanonical', () {
    test('resamples a linear ramp exactly (interior interpolation)', () {
      // A native grid coarser than, and offset from, the canonical grid so the
      // canonical bins fall strictly *between* native samples (exercises the
      // bracket/interpolate branch, not an exact-hit shortcut).
      final wavelengths = <double>[380, 420, 500, 620, 730];
      double ramp(double nm) => (nm - 400) / 300; // 0 at 400, 1 at 700
      final values = <double>[for (final nm in wavelengths) ramp(nm)];

      final out = resampleOntoCanonical(wavelengths, values);

      expect(out, isA<Float32List>());
      expect(out, hasLength(CanonicalGrid.bins));
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        final nm = CanonicalGrid.wavelengthAt(i);
        expect(out[i], closeTo(ramp(nm), 1e-5),
            reason: 'linear ramp must resample exactly at $nm nm');
      }
    });

    test('reproduces native samples that coincide with canonical bins', () {
      // Native 400–700 @ 10 nm: every canonical bin hits a native sample head-on
      // (nm == wavelengthsNm[j]), so t == 0 and the value is copied through.
      final wavelengths = <double>[for (var nm = 400.0; nm <= 700; nm += 10) nm];
      final values = <double>[for (var i = 0; i < wavelengths.length; i++) i.toDouble()];

      final out = resampleOntoCanonical(wavelengths, values);

      expect(out, hasLength(CanonicalGrid.bins));
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        expect(out[i], closeTo(i.toDouble(), 1e-5));
      }
    });

    test('clamps flat below and above the native range', () {
      // Native range 440–660 is strictly inside the canonical 400–700, so the
      // 400/410/420/430 bins clamp to the first value and 670..700 to the last.
      final wavelengths = <double>[440, 550, 660];
      final values = <double>[0.2, 0.6, 0.9];

      final out = resampleOntoCanonical(wavelengths, values);

      expect(out.first, closeTo(0.2, 1e-5)); // 400 nm < 440 → first
      expect(out[CanonicalGrid.bins ~/ 2], closeTo(0.6, 1e-5)); // 550 nm exact
      expect(out.last, closeTo(0.9, 1e-5)); // 700 nm > 660 → last
      // A canonical bin still inside the range interpolates normally.
      final atFourFifty = out[(450 - 400) ~/ 10];
      expect(atFourFifty, closeTo(0.2 + (450 - 440) / (550 - 440) * (0.6 - 0.2), 1e-5));
    });

    test('rejects mismatched list lengths', () {
      expect(
        () => resampleOntoCanonical(<double>[400, 500], <double>[0.1]),
        throwsArgumentError,
      );
    });

    test('rejects fewer than two samples', () {
      expect(
        () => resampleOntoCanonical(<double>[500], <double>[0.5]),
        throwsArgumentError,
      );
    });

    test('rejects non-ascending wavelengths', () {
      expect(
        () => resampleOntoCanonical(<double>[500, 500], <double>[0.1, 0.2]),
        throwsArgumentError,
      );
      expect(
        () => resampleOntoCanonical(<double>[500, 480], <double>[0.1, 0.2]),
        throwsArgumentError,
      );
    });
  });
}
