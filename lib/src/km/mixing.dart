import 'dart:typed_data';

import '../grid.dart';

/// A single weighted component of a two-constant mixture: a paint's absorption
/// spectrum [k], its scattering spectrum [s], and its [weight] — the
/// concentration, which for finished paints is simply the volume fraction
/// (design §5). Both spectra are on the [CanonicalGrid].
typedef MixComponent = ({Spectrum k, Spectrum s, double weight});

/// The two-constant Kubelka–Munk description of a mixture: its mixed absorption
/// [k] (`Kmix`) and scattering [s] (`Smix`) spectra on the [CanonicalGrid].
typedef KmMix = ({Spectrum k, Spectrum s});

/// Forms the two-constant Kubelka–Munk mixture of [components] (design §3.3):
/// the elementwise volume-weighted sums
///
/// ```
/// Kmix(λ) = Σ_i  v_i · K_i(λ)
/// Smix(λ) = Σ_i  v_i · S_i(λ)
/// ```
///
/// Carrying `S` separately rather than only the ratio `K/S` is the key upgrade
/// of the two-constant model: it is what lets opaque and transparent pigments
/// behave differently and makes real mixtures gray realistically (design §3.3).
///
/// The weights are concentrations. For finished paints — which the datasets
/// measure as applied (pigment + binder + fillers) — concentration *is* the
/// volume fraction (design §5), so parts-by-volume map directly onto these
/// weights. This primitive sums the weights exactly **as given** and does not
/// normalise them: volumes are normalised to sum 1 upstream in the forward model
/// (AC-14), so that AC's behaviour is not hidden here.
///
/// Two properties hold by construction (AC-5), because the result is a linear
/// sum:
///
/// * **Order-independent** — permuting [components] yields the same Kmix/Smix,
///   hence the same predicted colour. The per-wavelength sums accumulate in
///   double precision and narrow to the [Spectrum]'s `Float32` once at the end,
///   so reordering does not perturb the result at the spectrum's precision.
/// * **Self-mix idempotent** — splitting one paint across several components
///   whose weights total `w` is identical to that one paint at weight `w`; in
///   particular, mixing a paint with only itself at weights summing to 1
///   reproduces that paint's own K and S (and therefore its colour) at any
///   ratio.
///
/// Every component spectrum must have [CanonicalGrid.bins] samples and
/// [components] must be non-empty; otherwise throws [ArgumentError].
KmMix mixTwoConstant(List<MixComponent> components) {
  if (components.isEmpty) {
    throw ArgumentError.value(
      components,
      'components',
      'a mixture needs at least one component',
    );
  }
  const bins = CanonicalGrid.bins;
  // Accumulate in double precision so the narrowing to Float32 is the only
  // rounding step, keeping the sum independent of component order.
  final kAcc = Float64List(bins);
  final sAcc = Float64List(bins);
  for (final c in components) {
    CanonicalGrid.checkLength(c.k);
    CanonicalGrid.checkLength(c.s);
    final w = c.weight;
    for (var i = 0; i < bins; i++) {
      kAcc[i] += w * c.k[i];
      sAcc[i] += w * c.s[i];
    }
  }
  final k = Float32List(bins);
  final s = Float32List(bins);
  for (var i = 0; i < bins; i++) {
    k[i] = kAcc[i];
    s[i] = sAcc[i];
  }
  return (k: k, s: s);
}
