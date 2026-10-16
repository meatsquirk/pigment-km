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
  test('CustomKmEngine implements MixingEngine; forward model is live, '
      'inverse still stubbed (FORWARD-2)', () {
    const engine = CustomKmEngine();
    expect(engine, isA<MixingEngine>());
    // The forward model is now implemented (FORWARD-2): it resolves the paint id
    // against the loaded medium tables and runs the pipeline, so it does NOT
    // throw UnimplementedError on a real paint.
    const whiteId = 'acrylic.titanium_white';
    final colour = engine.forward(const {whiteId: 1.0});
    expect(colour, isA<ColourValue>());
    final reflectance = engine.reflectanceOf(const {whiteId: 1.0});
    expect(reflectance, hasLength(CanonicalGrid.bins));
    // forward == spectrumToColour(reflectanceOf): the two share one pipeline.
    expect(engine.forward(const {whiteId: 1.0}), colour);
    // The inverse solver is still a SOLVER-phase stub.
    expect(
      () => engine.inverse(_target, const [], const MixOptions()),
      throwsUnimplementedError,
    );
  });

  group('CustomKmEngine.forward resolution and guards', () {
    const engine = CustomKmEngine();

    test('resolves an oil-medium paint id (second medium table searched)', () {
      // Covers the resolver loop continuing past the acrylic table to oil.
      final oil = engine.forward(const {'oil.lead_white': 1.0});
      expect(oil, isA<ColourValue>());
    });

    test('an unknown paint id throws ArgumentError', () {
      expect(
        () => engine.forward(const {'acrylic.not_a_paint': 1.0}),
        throwsArgumentError,
      );
    });

    test('a mixture spanning two media throws ArgumentError', () {
      expect(
        () => engine.forward(const {
          'acrylic.titanium_white': 0.5,
          'oil.lead_white': 0.5,
        }),
        throwsArgumentError,
      );
    });

    test('an empty mixture throws ArgumentError', () {
      expect(() => engine.forward(const {}), throwsArgumentError);
    });

    test('parts summing to zero throw ArgumentError', () {
      expect(
        () => engine.forward(const {'acrylic.titanium_white': 0.0}),
        throwsArgumentError,
      );
    });
  });

  test('SpectralBaselineEngine implements MixingEngine and stubs throw', () {
    const engine = SpectralBaselineEngine();
    expect(engine, isA<MixingEngine>());
    _behavesAsUnimplementedStub(engine);
  });
}
