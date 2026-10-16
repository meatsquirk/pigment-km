import '../grid.dart';
import '../types/colour_value.dart';
import '../types/mix_options.dart';
import '../types/pigment.dart';
import '../types/recipe.dart';
import 'mixing_engine.dart';

/// The measured-pigment, two-constant Kubelka–Munk engine (design §6, §10).
///
/// Shell stub: the behaviour phases (COLOR, KM, DATA, FORWARD, SOLVER, TUNE)
/// fill the forward model (Σ v·K, Σ v·S → KM → Saunderson → spectrum → XYZ →
/// sRGB) and the inverse solver. Every method throws [UnimplementedError] until
/// its phase lands.
class CustomKmEngine implements MixingEngine {
  const CustomKmEngine();

  @override
  ColourValue forward(Map<String, double> mix) =>
      throw UnimplementedError('CustomKmEngine.forward — FORWARD phases');

  @override
  List<Recipe> inverse(
    ColourValue target,
    List<Pigment> palette,
    MixOptions opts,
  ) =>
      throw UnimplementedError('CustomKmEngine.inverse — SOLVER phases');

  @override
  Spectrum reflectanceOf(Map<String, double> mix) =>
      throw UnimplementedError('CustomKmEngine.reflectanceOf — FORWARD phases');
}
