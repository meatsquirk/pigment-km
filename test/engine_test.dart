import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

const _target = ColourValue(
  srgb: (r: 0.1, g: 0.2, b: 0.3),
  xyz: (x: 0.4, y: 0.5, z: 0.6),
  oklch: (l: 0.7, c: 0.1, h: 120.0),
);

void _behavesAsUnimplementedStub(MixingEngine engine) {
  expect(() => engine.forward(const {'a': 1.0}), throwsUnimplementedError);
  expect(
    () => engine.inverse(_target, const [], const MixOptions()),
    throwsUnimplementedError,
  );
  expect(() => engine.reflectanceOf(const {'a': 1.0}), throwsUnimplementedError);
}

void main() {
  test('CustomKmEngine implements MixingEngine and stubs throw', () {
    const engine = CustomKmEngine();
    expect(engine, isA<MixingEngine>());
    _behavesAsUnimplementedStub(engine);
  });

  test('SpectralBaselineEngine implements MixingEngine and stubs throw', () {
    const engine = SpectralBaselineEngine();
    expect(engine, isA<MixingEngine>());
    _behavesAsUnimplementedStub(engine);
  });
}
