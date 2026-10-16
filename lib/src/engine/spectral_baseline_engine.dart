import '../grid.dart';
import '../types/colour_value.dart';
import '../types/mix_options.dart';
import '../types/pigment.dart';
import '../types/recipe.dart';
import 'mixing_engine.dart';

/// The single-constant spectral baseline engine (design §8 S0/S5).
///
/// Implements the same [MixingEngine] interface as [CustomKmEngine] so the two
/// are interchangeable and the A/B harness can report each one's ΔE00 on the
/// same swatch set (AC-25). Shell stub: every method throws [UnimplementedError]
/// until the baseline behaviour phase lands.
class SpectralBaselineEngine implements MixingEngine {
  const SpectralBaselineEngine();

  @override
  ColourValue forward(Map<String, double> mix) =>
      throw UnimplementedError('SpectralBaselineEngine.forward — PROD phases');

  @override
  List<Recipe> inverse(
    ColourValue target,
    List<Pigment> palette,
    MixOptions opts,
  ) =>
      throw UnimplementedError('SpectralBaselineEngine.inverse — PROD phases');

  @override
  Spectrum reflectanceOf(Map<String, double> mix) => throw UnimplementedError(
        'SpectralBaselineEngine.reflectanceOf — PROD phases',
      );
}
