/// pigment_km — measured-pigment, two-constant Kubelka–Munk colour mixing.
///
/// Public surface: the canonical spectral grid and [Spectrum] alias, the colour
/// and pigment value types, the solver options, and the swappable
/// [MixingEngine] interface with its measured-pigment and baseline
/// implementations. The engine bodies are filled in by the behaviour phases;
/// this library pins the contract they build against.
library;

export 'src/data/artifact_format.dart';
export 'src/data/pigment_table.dart';
export 'src/engine/custom_km_engine.dart';
export 'src/engine/mixing_engine.dart';
export 'src/engine/spectral_baseline_engine.dart';
export 'src/grid.dart';
export 'src/types/colour_value.dart';
export 'src/types/medium.dart';
export 'src/types/mix_options.dart';
export 'src/types/pigment.dart';
export 'src/types/provenance.dart';
export 'src/types/recipe.dart';
