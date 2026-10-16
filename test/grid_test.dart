import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

void main() {
  group('CanonicalGrid', () {
    test('constants describe a 400–700 nm @ 10 nm, 31-bin grid', () {
      expect(CanonicalGrid.start, 400);
      expect(CanonicalGrid.end, 700);
      expect(CanonicalGrid.step, 10);
      expect(CanonicalGrid.bins, 31);
      expect(
        (CanonicalGrid.end - CanonicalGrid.start) / CanonicalGrid.step + 1,
        CanonicalGrid.bins,
      );
    });

    test('wavelengthAt maps bins to wavelengths', () {
      expect(CanonicalGrid.wavelengthAt(0), 400);
      expect(CanonicalGrid.wavelengthAt(1), 410);
      expect(CanonicalGrid.wavelengthAt(30), 700);
    });

    test('wavelengthAt rejects out-of-range bins', () {
      expect(() => CanonicalGrid.wavelengthAt(-1), throwsRangeError);
      expect(() => CanonicalGrid.wavelengthAt(31), throwsRangeError);
    });

    test('checkLength returns a correctly sized spectrum', () {
      final s = Float32List(CanonicalGrid.bins);
      expect(identical(CanonicalGrid.checkLength(s), s), isTrue);
    });

    test('checkLength rejects a wrongly sized spectrum', () {
      expect(
        () => CanonicalGrid.checkLength(Float32List(10)),
        throwsArgumentError,
      );
    });
  });

  group('spectraEqual / spectrumHash', () {
    Spectrum ramp() => Float32List.fromList([0, 0.5, 1]);

    test('equal contents compare equal and hash equal', () {
      final a = ramp();
      final b = ramp();
      expect(spectraEqual(a, b), isTrue);
      expect(spectrumHash(a), spectrumHash(b));
    });

    test('different length is not equal', () {
      expect(
        spectraEqual(Float32List.fromList([0, 1]), Float32List.fromList([0])),
        isFalse,
      );
    });

    test('different value is not equal', () {
      expect(
        spectraEqual(
          Float32List.fromList([0, 1, 0]),
          Float32List.fromList([0, 0, 0]),
        ),
        isFalse,
      );
    });
  });
}
