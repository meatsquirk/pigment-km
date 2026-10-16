import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

void main() {
  test('package loads and exposes its public surface', () {
    expect(CanonicalGrid.bins, 31);
    expect(const CustomKmEngine(), isA<MixingEngine>());
    expect(const SpectralBaselineEngine(), isA<MixingEngine>());
  });
}
