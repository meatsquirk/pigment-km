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
/// / CIE 1964 10° by [spectrumToColour].
ColourValue forwardColour(Map<String, double> mix, PigmentResolver resolve) =>
    spectrumToColour(forwardReflectance(mix, resolve));

/// A forward evaluator bound to one fixed, single-medium set of [Pigment]s
/// (SOLVER-7 performance, AC-20).
///
/// The inverse solver evaluates the same handful of paints at hundreds of
/// different volume-share vectors while fitting a subset (the coarse grid then
/// the refinement hill-climb), and [forwardColour] re-resolves the ids, re-reads
/// the pigments, rebuilds the component list and re-validates the spectra on
/// *every* call. [BoundForward] reads the paints' absorption/scattering spectra
/// and the medium's Saunderson config **once** in its factory, then [colourFor]
/// predicts the colour of any share vector over those paints while reusing its
/// internal accumulation buffers — so the solver's inner loop allocates almost
/// nothing per evaluation.
///
/// [colourFor] reproduces [forwardColour] exactly: the shares are normalized to
/// sum 1 (design §5; AC-14), the two-constant `Kmix`/`Smix` are accumulated in
/// double precision and narrowed to `Float32` once (matching [mixTwoConstant]),
/// then taken through `K/S` → opaque Kubelka–Munk reflectance ([kmReflectance])
/// → Saunderson surface correction ([saundersonToMeasured]) → colour
/// ([spectrumToColour]) in the paints' given order. It is therefore a pure
/// performance optimization: a bound evaluation and the equivalent
/// [forwardColour] call return bit-identical colours.
class BoundForward {
  BoundForward._(this._n, this._k, this._s, this._config);

  /// Binds the evaluator to [paints]. [paints] must be non-empty and all of one
  /// medium (a single mixture never spans media — see [forwardReflectance]);
  /// otherwise throws [ArgumentError]. Each paint's spectra are length-checked
  /// here, once, rather than on every evaluation.
  factory BoundForward(List<Pigment> paints) {
    if (paints.isEmpty) {
      throw ArgumentError.value(
        paints,
        'paints',
        'a mixture needs at least one paint',
      );
    }
    final medium = paints.first.medium;
    final k = <Spectrum>[];
    final s = <Spectrum>[];
    for (final p in paints) {
      if (p.medium != medium) {
        throw ArgumentError.value(
          paints,
          'paints',
          'a single mixture must not span media '
              '(${medium.name} vs ${p.medium.name})',
        );
      }
      CanonicalGrid.checkLength(p.k);
      CanonicalGrid.checkLength(p.s);
      k.add(p.k);
      s.add(p.s);
    }
    return BoundForward._(paints.length, k, s, configForMedium(medium));
  }

  final int _n;
  final List<Spectrum> _k;
  final List<Spectrum> _s;
  final MediumConfig _config;

  final Float64List _kAcc = Float64List(CanonicalGrid.bins);
  final Float64List _sAcc = Float64List(CanonicalGrid.bins);
  final Float32List _kMix = Float32List(CanonicalGrid.bins);
  final Float32List _sMix = Float32List(CanonicalGrid.bins);
  final Float32List _koverS = Float32List(CanonicalGrid.bins);

  /// The predicted colour of the bound paints mixed at volume [shares] (one
  /// share per bound paint, in bind order). [shares] must sum to a positive
  /// total — the inverse solver only ever passes strictly-positive simplex
  /// points, so this is not re-checked on the hot path.
  ColourValue colourFor(List<double> shares) {
    const bins = CanonicalGrid.bins;
    var total = 0.0;
    for (var i = 0; i < _n; i++) {
      total += shares[i];
    }
    for (var b = 0; b < bins; b++) {
      _kAcc[b] = 0;
      _sAcc[b] = 0;
    }
    for (var i = 0; i < _n; i++) {
      final w = shares[i] / total;
      final ki = _k[i];
      final si = _s[i];
      for (var b = 0; b < bins; b++) {
        _kAcc[b] += w * ki[b];
        _sAcc[b] += w * si[b];
      }
    }
    for (var b = 0; b < bins; b++) {
      _kMix[b] = _kAcc[b];
      _sMix[b] = _sAcc[b];
      _koverS[b] = _kMix[b] / _sMix[b];
    }
    final internal = kmReflectance(_koverS);
    final measured = saundersonToMeasured(internal, _config);
    return spectrumToColour(measured);
  }
}
