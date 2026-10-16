/// pigment_km — measured-pigment, two-constant Kubelka–Munk colour mixing.
///
/// Public surface: the canonical spectral grid and [Spectrum] alias, the colour
/// and pigment value types, the solver options, and the swappable
/// [MixingEngine] interface with its measured-pigment and baseline
/// implementations, plus the colour, KM-physics and ingest backend functions.
/// The engine and backend bodies are filled in by the behaviour phases; this
/// library pins the contract they build against (the backend functions are
/// `UnimplementedError` stubs until their COLOR/KM/DATA phase lands).
library;

export 'src/colour/gamut_map.dart';
export 'src/colour/spectrum_to_colour.dart';
export 'src/data/artifact_format.dart';
export 'src/data/masstone_tint.dart';
export 'src/data/pigment_table.dart';
export 'src/data/resample.dart';
export 'src/engine/custom_km_engine.dart';
export 'src/engine/mixing_engine.dart';
export 'src/engine/spectral_baseline_engine.dart';
export 'src/grid.dart';
export 'src/km/mixing.dart';
export 'src/km/reflectance.dart';
export 'src/km/saunderson.dart';
export 'src/types/colour_value.dart';
export 'src/types/medium.dart';
export 'src/types/mix_options.dart';
export 'src/types/pigment.dart';
export 'src/types/provenance.dart';
export 'src/types/recipe.dart';
