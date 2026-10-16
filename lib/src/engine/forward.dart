import 'dart:typed_data';

import '../colour/spectrum_to_colour.dart';
import '../grid.dart';
import '../km/mixing.dart';
import '../km/reflectance.dart';
import '../km/saunderson.dart';
import '../types/colour_value.dart';
import '../types/medium.dart';
import '../types/pigment.dart';

/// Resolves a paint id to its [Pigment] record. The forward model is given one
/// of these so it stays independent of where the pigment tables come from (the
/// engine supplies a resolver over the loaded medium tables).
typedef PigmentResolver = Pigment Function(String id);

/// Normalizes parts-by-volume so the weights sum to 1 (design §5; AC-14).
///
/// The datasets measure finished paints (pigment + binder + fillers), for which
/// the concentration *is* the volume fraction, so parts-by-volume map directly
/// onto the two-constant mixing weights once rescaled to sum 1. Any positive
/// scaling of the same ratio therefore yields the same colour. [parts] must be
/// non-empty and its values must sum to a positive total; otherwise throws
/// [ArgumentError].
Map<String, double> normalizeParts(Map<String, double> parts) {
  if (parts.isEmpty) {
    throw ArgumentError.value(parts, 'parts', 'a mixture needs at least one paint');
  }
  var total = 0.0;
  for (final v in parts.values) {
    total += v;
  }
  if (total <= 0) {
    throw ArgumentError.value(
      parts,
      'parts',
      'the parts-by-volume must sum to a positive total',
    );
  }
  return <String, double>{
    for (final e in parts.entries) e.key: e.value / total,
  };
}

/// The predicted measured reflectance spectrum of the mixture [mix] (design
/// §6.1 forward model).
///
/// Composes the whole forward pipeline: normalize the parts to Σ1 → resolve each
/// id to its pigment via [resolve] → two-constant mix ([mixTwoConstant], the
/// volume-weighted `Kmix`, `Smix`) → per-wavelength `K/S` → opaque Kubelka–Munk
/// reflectance ([kmReflectance], the internal body reflectance) → Saunderson
/// surface correction for the mixture's medium ([saundersonToMeasured]) → the
/// measured reflectance a spectrophotometer would read. This is the read
/// endpoint the acceptance suite observes for spectral assertions.
///
/// Every paint in [mix] must belong to the same [Medium] (a single mixture
/// never spans media — see [MixingEngine]); otherwise throws [ArgumentError].
Spectrum forwardReflectance(Map<String, double> mix, PigmentResolver resolve) {
  final weights = normalizeParts(mix);
  final components = <MixComponent>[];
  Medium? medium;
  for (final e in weights.entries) {
    final pigment = resolve(e.key);
    medium ??= pigment.medium;
    if (pigment.medium != medium) {
      throw ArgumentError.value(
        mix,
        'mix',
        'a single mixture must not span media '
            '(${medium.name} vs ${pigment.medium.name})',
      );
    }
    components.add((k: pigment.k, s: pigment.s, weight: e.value));
  }
  final kmMix = mixTwoConstant(components);
  final koverS = Float32List(CanonicalGrid.bins);
  for (var i = 0; i < CanonicalGrid.bins; i++) {
    koverS[i] = kmMix.k[i] / kmMix.s[i];
  }
  final internal = kmReflectance(koverS);
  return saundersonToMeasured(internal, configForMedium(medium!));
}

/// The predicted colour of the mixture [mix] (design §6.1): the measured
/// reflectance from [forwardReflectance] converted to a [ColourValue] under D65
/// / CIE 1931 by [spectrumToColour].
ColourValue forwardColour(Map<String, double> mix, PigmentResolver resolve) =>
    spectrumToColour(forwardReflectance(mix, resolve));
