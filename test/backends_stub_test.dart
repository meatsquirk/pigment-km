import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

/// Unit coverage for the public backend stubs added in ITEST-2 (Option A): the
/// COLOR, KM-physics and ingest functions the acceptance suite calls through.
///
/// Each is an `UnimplementedError` stub until its behaviour phase (named in the
/// message) fills the body; this suite pins that contract and keeps the new
/// files fully covered in the default run (the acceptance red-baseline run
/// exercises them through the AC tests, but that run is pending-gated).
void main() {
  final spectrum = Float32List.fromList(
    List<double>.filled(CanonicalGrid.bins, 0.5),
  );
  const config = MediumConfig(medium: Medium.acrylic, k1: 0.04, k2: 0.6);

  const target = ColourValue(
    srgb: (r: 0.1, g: 0.2, b: 0.3),
    xyz: (x: 0.4, y: 0.5, z: 0.6),
    oklch: (l: 0.7, c: 0.1, h: 120.0),
  );

  group('COLOR backend stubs throw their documented UnimplementedError', () {
    test('spectrumToColour — COLOR-2', () {
      expect(() => spectrumToColour(spectrum), throwsUnimplementedError);
    });
    test('gamutMap — COLOR-3', () {
      expect(() => gamutMap(target), throwsUnimplementedError);
    });
  });

  group('KM physics stubs throw their documented UnimplementedError', () {
    test('kmReflectance — KM-2', () {
      expect(() => kmReflectance(spectrum), throwsUnimplementedError);
    });
    test('kmFunction — KM-2', () {
      expect(() => kmFunction(spectrum), throwsUnimplementedError);
    });
    test('configForMedium — KM-3', () {
      expect(() => configForMedium(Medium.acrylic), throwsUnimplementedError);
    });
    test('saundersonToMeasured — KM-3', () {
      expect(
        () => saundersonToMeasured(spectrum, config),
        throwsUnimplementedError,
      );
    });
    test('saundersonToInternal — KM-3', () {
      expect(
        () => saundersonToInternal(spectrum, config),
        throwsUnimplementedError,
      );
    });
  });

  group('ingest stub throws its documented UnimplementedError', () {
    test('resampleOntoCanonical — DATA-2', () {
      expect(
        () => resampleOntoCanonical(const <double>[400, 700], const <double>[0, 1]),
        throwsUnimplementedError,
      );
    });
    test('deriveKsFromMasstoneTint — DATA-4 (added ITEST-3, Option A)', () {
      expect(
        () => deriveKsFromMasstoneTint(
          masstone: spectrum,
          tints: <Tint>[(pigmentFraction: 0.5, reflectance: spectrum)],
          whiteK: spectrum,
          whiteS: spectrum,
        ),
        throwsUnimplementedError,
      );
    });
  });
}
