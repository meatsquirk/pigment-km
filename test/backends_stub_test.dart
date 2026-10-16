import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

/// Unit coverage for the public backend stubs added in ITEST-2 (Option A) that
/// are still pending: the ingest functions the acceptance suite calls through.
///
/// Each is an `UnimplementedError` stub until its behaviour phase (named in the
/// message) fills the body; this suite pins that contract and keeps the new
/// files fully covered in the default run (the acceptance red-baseline run
/// exercises them through the AC tests, but that run is pending-gated). The
/// COLOR stubs (`spectrumToColour`, `gamutMap`) are now implemented — covered by
/// test/colour_test.dart and test/gamut_map_test.dart.
void main() {
  final spectrum = Float32List.fromList(
    List<double>.filled(CanonicalGrid.bins, 0.5),
  );

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
