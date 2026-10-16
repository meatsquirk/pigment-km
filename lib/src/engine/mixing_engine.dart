import '../grid.dart';
import '../types/colour_value.dart';
import '../types/mix_options.dart';
import '../types/pigment.dart';
import '../types/recipe.dart';

/// The swappable mixing-engine contract (SI D3; design §10).
///
/// Both the measured-pigment Kubelka–Munk engine and the single-constant
/// baseline implement this identical surface, so callers can A/B them with no
/// change (design §8 S0/S5). A single call never spans media.
abstract interface class MixingEngine {
  /// Predicts the colour of a mixture given pigment id → volume fraction.
  ColourValue forward(Map<String, double> mix);

  /// Returns up to [MixOptions.topK] recipes for [target] drawn only from
  /// [palette], ranked best-first by ΔE00 (preferring fewer paints on a tie).
  List<Recipe> inverse(
    ColourValue target,
    List<Pigment> palette,
    MixOptions opts,
  );

  /// The predicted reflectance spectrum of a mixture — the read endpoint the
  /// acceptance suite uses for spectral assertions and metamerism checks.
  Spectrum reflectanceOf(Map<String, double> mix);
}
