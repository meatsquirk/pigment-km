import '../data/pigment_table.dart';
import '../grid.dart';
import '../types/colour_value.dart';
import '../types/medium.dart';
import '../types/mix_options.dart';
import '../types/pigment.dart';
import '../types/recipe.dart';
import 'forward.dart';
import 'inverse.dart';
import 'mixing_engine.dart';

/// The measured-pigment, two-constant Kubelka–Munk engine (design §6, §10).
///
/// The forward model ([forward]/[reflectanceOf]) composes the two-constant
/// mixing (Σ v·K, Σ v·S) → Kubelka–Munk reflectance → Saunderson surface
/// correction → spectrum → colour pipeline (see [forwardReflectance]); the
/// inverse solver is the palette-constrained search ([solvePaletteConstrained],
/// SOLVER-2), with the remaining SOLVER phases layering ranking, out-of-gamut
/// flagging, the cross-medium partition, accuracy and performance on top.
class CustomKmEngine implements MixingEngine {
  const CustomKmEngine();

  @override
  ColourValue forward(Map<String, double> mix) => forwardColour(mix, _resolve);

  @override
  Spectrum reflectanceOf(Map<String, double> mix) =>
      forwardReflectance(mix, _resolve);

  @override
  List<Recipe> inverse(
    ColourValue target,
    List<Pigment> palette,
    MixOptions opts,
  ) =>
      solvePaletteConstrained(target, palette, opts);

  /// Resolves a paint [id] to its [Pigment] by searching the loaded pigment
  /// table of each medium (design §4). Throws [ArgumentError] if no medium's
  /// table holds the id.
  static Pigment _resolve(String id) {
    for (final medium in Medium.values) {
      final pigment = PigmentTable.load(medium).byId(id);
      if (pigment != null) {
        return pigment;
      }
    }
    throw ArgumentError.value(id, 'id', 'no paint with this id in any medium table');
  }
}
