import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

void main() {
  const measured = CustomKmEngine();
  const baseline = SpectralBaselineEngine();
  final palette = PigmentTable.load(Medium.acrylic).pigments;

  // A swatch set in the palette's gamut, each built as a real mixture so both
  // engines can match it — the same set every engine is scored on.
  final swatches = <ColourValue>[
    measured.forward(const {'acrylic.titanium_white': 0.7, 'acrylic.phthalo_blue': 0.3}),
    measured.forward(const {'acrylic.titanium_white': 0.5, 'acrylic.naphthol_red': 0.5}),
  ];

  test('run drives both engines through the identical interface and reports '
      'each one ΔE00 per swatch on the same set', () {
    final harness = ABHarness(
      engines: <String, MixingEngine>{
        'measured': measured,
        'baseline': baseline,
      },
      palette: palette,
    );
    final report = harness.run(swatches);

    expect(report.swatchCount, swatches.length);
    expect(report.engines, orderedEquals(<String>['measured', 'baseline']));
    for (final label in report.engines) {
      final deltas = report.deltaE00For(label);
      expect(deltas, hasLength(swatches.length));
      for (final d in deltas) {
        expect(d, isNonNegative);
        expect(d.isFinite, isTrue);
      }
      // The mean is the average of the per-swatch distances.
      final sum = deltas.fold<double>(0, (a, b) => a + b);
      expect(report.meanDeltaE00For(label), closeTo(sum / deltas.length, 1e-12));
    }
    // deltaE00For hands back a read-only view.
    expect(() => report.deltaE00For('measured').add(0), throwsUnsupportedError);
  });

  test('an engine that returns no recipe (empty palette) reports infinity for '
      'that swatch', () {
    const harness = ABHarness(
      engines: <String, MixingEngine>{'baseline': baseline},
      palette: <Pigment>[],
    );
    final report = harness.run(swatches);
    expect(report.deltaE00For('baseline'),
        everyElement(predicate<double>((d) => d == double.infinity)));
  });

  test('deltaE00For an unknown engine label throws ArgumentError', () {
    final report = ABHarness(
      engines: <String, MixingEngine>{'baseline': baseline},
      palette: palette,
    ).run(swatches);
    expect(() => report.deltaE00For('nope'), throwsArgumentError);
    expect(() => report.meanDeltaE00For('nope'), throwsArgumentError);
  });

  test('the mean of a zero-swatch run is undefined and throws StateError', () {
    final report = ABHarness(
      engines: <String, MixingEngine>{'baseline': baseline},
      palette: palette,
    ).run(const <ColourValue>[]);
    expect(report.swatchCount, 0);
    expect(report.deltaE00For('baseline'), isEmpty);
    expect(() => report.meanDeltaE00For('baseline'), throwsStateError);
  });
}
