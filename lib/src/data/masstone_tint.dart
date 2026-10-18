import 'dart:math' as math;
import 'dart:typed_data';

import '../grid.dart';

/// One tint in a masstone–tint series (design §4.4): the pigment mixed with
/// white at a known [pigmentFraction] (a volume fraction in `(0, 1]`, white
/// making up the remainder `1 - pigmentFraction`), and the [reflectance]
/// measured for that tint on the canonical grid. The masstone is the degenerate
/// tint at `pigmentFraction == 1` (pure pigment, no white).
typedef Tint = ({double pigmentFraction, Spectrum reflectance});

/// Physical reflectance is clamped into `[_minReflectance, 1]` before the
/// Kubelka–Munk inversion `K/S = (1 − R)² / (2R)`, so a user-measured tube that
/// reads `0` (or a hair below it) stays finite instead of dividing by zero.
const double _minReflectance = 1e-6;

/// Below this the per-wavelength 2×2 normal matrix is treated as singular: the
/// masstone + tints do not separate `K` from `S` at that wavelength (see
/// [deriveKsFromMasstoneTint]).
const double _singularDet = 1e-12;

/// Derives a pigment's two-constant Kubelka–Munk absorption [Spectrum] `k` and
/// scattering `s` from its [masstone] reflectance and a [tints] series mixed
/// with a white of known [whiteK], [whiteS], by per-wavelength least squares
/// across the series (design §4.4; AC-10).
///
/// The masstone alone fixes only the ratio `K/S` at each wavelength (the opaque
/// reflectance depends on `K/S`, not on `K` and `S` separately); the tint series
/// with a known white separates `K` from `S`, because mixing shifts the
/// volume-weighted `K` and `S` by the pigment fraction. This is the hook for
/// K,S derived from a user's own measured tube.
///
/// **Model.** Each sample (the masstone, plus every tint) is the pigment at its
/// volume fraction `c` mixed with the white at `1 − c`, so its mix constants are
/// the volume-weighted sums `K_mix = c·K + (1−c)·K_w` and
/// `S_mix = c·S + (1−c)·S_w`. Inverting the opaque Kubelka–Munk reflectance
/// gives the measured ratio `x = K_mix / S_mix = (1 − R)² / (2R)` (the same
/// function as `kmFunction`, with a physical-range clamp on `R`). Rearranging
/// `K_mix = x·S_mix` into the two unknowns `(K, S)` yields, per sample, the
/// linear equation
///
/// ```
/// c·K − (x·c)·S = x·(1−c)·S_w − (1−c)·K_w
/// ```
///
/// The masstone (`c = 1`) contributes `K − x_m·S = 0`, i.e. fixes `K/S = x_m`;
/// each tint (`c < 1`) adds the white's own `(K_w, S_w)` to the right-hand side,
/// which is what breaks the ratio degeneracy and separates `K` from `S`. The
/// per-wavelength 2×2 least-squares solution recovers `(K, S)`; on noise-free
/// data the fit is exact, so the derived constants reproduce every tint and the
/// masstone.
///
/// Throws [ArgumentError] when any spectrum is off the canonical grid, when
/// [tints] is empty, or when a tint fraction is outside `(0, 1]`, and
/// [StateError] when a wavelength's normal matrix is singular — the white's
/// `K/S` equals the pigment's there (or the fractions coincide), so no series
/// can separate `K` from `S` at that wavelength.
({Spectrum k, Spectrum s}) deriveKsFromMasstoneTint({
  required Spectrum masstone,
  required List<Tint> tints,
  required Spectrum whiteK,
  required Spectrum whiteS,
}) {
  CanonicalGrid.checkLength(masstone);
  CanonicalGrid.checkLength(whiteK);
  CanonicalGrid.checkLength(whiteS);
  if (tints.isEmpty) {
    throw ArgumentError.value(tints, 'tints',
        'at least one tint (with white) is needed to separate K from S');
  }
  for (final t in tints) {
    CanonicalGrid.checkLength(t.reflectance);
    if (t.pigmentFraction <= 0.0 || t.pigmentFraction > 1.0) {
      throw ArgumentError.value(t.pigmentFraction, 'tint.pigmentFraction',
          'a tint pigment fraction must lie in (0, 1]');
    }
  }

  // The masstone is the degenerate tint at c = 1; least squares runs over it
  // together with every supplied tint.
  final samples = <Tint>[
    (pigmentFraction: 1.0, reflectance: masstone),
    ...tints,
  ];

  final k = Float32List(CanonicalGrid.bins);
  final s = Float32List(CanonicalGrid.bins);
  for (var i = 0; i < CanonicalGrid.bins; i++) {
    final kw = whiteK[i];
    final sw = whiteS[i];
    // Normal-equation accumulators for a_j·K + b_j·S = r_j across samples j.
    var saa = 0.0, sab = 0.0, sbb = 0.0, sar = 0.0, sbr = 0.0;
    for (final sample in samples) {
      final c = sample.pigmentFraction;
      final r = math.min(1.0, math.max(_minReflectance, sample.reflectance[i]));
      final oneMinusR = 1 - r;
      final x = (oneMinusR * oneMinusR) / (2 * r); // K_mix / S_mix at this λ.
      final a = c;
      final b = -x * c;
      final rhs = x * (1 - c) * sw - (1 - c) * kw;
      saa += a * a;
      sab += a * b;
      sbb += b * b;
      sar += a * rhs;
      sbr += b * rhs;
    }
    final det = saa * sbb - sab * sab;
    if (det.abs() < _singularDet || !det.isFinite) {
      throw StateError('the masstone + tint series does not separate K from S '
          'at ${CanonicalGrid.wavelengthAt(i)} nm (the white shares the '
          "pigment's K/S there, or the tint fractions coincide)");
    }
    // Clamp to the physical range (K, S ≥ 0; S strictly positive for a defined
    // K/S). On valid noise-free data the solution is already positive, so this
    // only guards degenerate user input.
    k[i] = math.max(0.0, (sbb * sar - sab * sbr) / det);
    s[i] = math.max(_minReflectance, (saa * sbr - sab * sar) / det);
  }
  return (k: k, s: s);
}
