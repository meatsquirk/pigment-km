import '../engine/mixing_engine.dart';
import '../types/colour_value.dart';
import '../types/mix_options.dart';
import '../types/pigment.dart';

/// The A/B evaluation harness (design §8 S0).
///
/// Drives two or more [MixingEngine]s — typically the measured-pigment
/// [CustomKmEngine] and the single-constant [SpectralBaselineEngine] — through
/// the *same* [MixingEngine.inverse] call on the *same* palette, options and
/// swatch set, and reports each engine's best-recipe ΔE00 per swatch. Because
/// every engine is driven through the identical interface with no per-engine
/// caller change, the per-swatch distances are directly comparable — the
/// measurement that shows whether the measured-pigment model matches targets
/// more closely than the baseline (AC-25, SI D3).
class ABHarness {
  const ABHarness({
    required this.engines,
    required this.palette,
    this.opts = const MixOptions(),
  });

  /// The engines under comparison, keyed by a label (e.g. `'measured'`,
  /// `'baseline'`); the label names each engine's column in the [ABReport].
  final Map<String, MixingEngine> engines;

  /// The palette every solve draws from — shared across engines so the only
  /// thing that varies between columns is the engine.
  final List<Pigment> palette;

  /// The solve options, shared across engines for the same reason.
  final MixOptions opts;

  /// Solves every [swatches] target with each engine and reports each engine's
  /// best-recipe ΔE00 per swatch, in swatch order. All engines see the identical
  /// `inverse(target, palette, opts)` call. An engine that returns no recipe for
  /// a swatch (e.g. an empty palette) reports [double.infinity] for it, so the
  /// report always has one finite-or-infinite distance per engine per swatch.
  ABReport run(List<ColourValue> swatches) => ABReport(
        swatchCount: swatches.length,
        deltaE00ByEngine: <String, List<double>>{
          for (final entry in engines.entries)
            entry.key: <double>[
              for (final target in swatches) _bestDelta(entry.value, target),
            ],
        },
      );

  double _bestDelta(MixingEngine engine, ColourValue target) {
    final recipes = engine.inverse(target, palette, opts);
    if (recipes.isEmpty) {
      return double.infinity;
    }
    return recipes.first.deltaE00;
  }
}

/// The result of an [ABHarness.run]: each engine's best-recipe ΔE00 per swatch,
/// on one shared swatch set.
class ABReport {
  const ABReport({
    required this.swatchCount,
    required Map<String, List<double>> deltaE00ByEngine,
  }) : _deltaE00ByEngine = deltaE00ByEngine;

  /// How many swatches each engine was scored on.
  final int swatchCount;

  final Map<String, List<double>> _deltaE00ByEngine;

  /// The labels of the engines compared, in insertion order.
  Iterable<String> get engines => _deltaE00ByEngine.keys;

  /// Engine [label]'s best-recipe ΔE00 per swatch, in swatch order. Throws
  /// [ArgumentError] if no engine was run under [label].
  List<double> deltaE00For(String label) {
    final row = _deltaE00ByEngine[label];
    if (row == null) {
      throw ArgumentError.value(label, 'label', 'no engine ran under this label');
    }
    return List<double>.unmodifiable(row);
  }

  /// The mean best-recipe ΔE00 for engine [label] across the swatch set — the
  /// headline A/B number (lower is the closer-matching engine). Throws
  /// [ArgumentError] if no engine ran under [label], or [StateError] if the run
  /// scored no swatches (an empty mean is undefined).
  double meanDeltaE00For(String label) {
    final row = deltaE00For(label);
    if (row.isEmpty) {
      throw StateError('no swatches were scored, so there is no mean ΔE00');
    }
    var sum = 0.0;
    for (final d in row) {
      sum += d;
    }
    return sum / row.length;
  }
}
