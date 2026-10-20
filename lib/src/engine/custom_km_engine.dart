import '../data/pigment_table.dart';
import '../grid.dart';
import '../km/saunderson.dart';
import '../tune/default_palettes.dart';
import '../tune/wet_dry.dart';
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
  ) {
    // The solve always works in the paint's wet state (the model's native
    // prediction), so the recipes, their ranking and their ΔE00 match distances
    // are identical for wet and dry (TUNE-4 / AC-23, gate G-2 — the wet/dry
    // choice is a display state, not a solver parameter). When the dry state is
    // requested each recipe is re-rendered through the medium's documented
    // drying offset ([configForMedium] → [WetDryTransform]) without re-solving:
    // only the predicted colour moves, the parts stay put.
    final recipes = solvePaletteConstrained(target, palette, opts);
    if (opts.wet) {
      return recipes;
    }
    return <Recipe>[
      for (final recipe in recipes)
        toDryState(recipe, configForMedium(recipe.medium).wetDry),
    ];
  }

  /// Resolves a paint [id] to its [Pigment] by searching the loaded pigment
  /// table of each medium (design §4), then the curated default palette
  /// ([defaultPaletteById], design §7 lever 1 — its real paints are not in the
  /// synthetic solver tables). Throws [ArgumentError] if nothing holds the id.
  static Pigment _resolve(String id) {
    for (final medium in Medium.values) {
      final pigment = PigmentTable.load(medium).byId(id);
      if (pigment != null) {
        return pigment;
      }
    }
    final curated = defaultPaletteById(id);
    if (curated != null) {
      return curated;
    }
    throw ArgumentError.value(
      id,
      'id',
      'no paint with this id in any medium table or the curated default palette',
    );
  }
}
