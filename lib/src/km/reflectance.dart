import 'dart:math' as math;
import 'dart:typed_data';

import '../grid.dart';

/// The Kubelka–Munk reflectance of a per-wavelength K/S ratio, opaque
/// (infinite-thickness) form (design §3.1, D-5; AC-3).
///
/// Elementwise `R∞ = 1 + x − sqrt(x² + 2x)` where `x = K/S`, over the whole
/// [CanonicalGrid]. [koverS] is the per-wavelength K/S spectrum; the result is
/// its reflectance spectrum, one sample per input sample.
///
/// This is the physical (`−√`) root: it is ≤ 1 for every `x ≥ 0`, so the
/// reflectance is bounded in `[0, 1]`. The other root `1 + x + √(x²+2x)` is its
/// reciprocal and lies above 1; the two map to the same K/S under [kmFunction],
/// so only the range distinguishes them (see `TestAC03_KmRoundTrip`). At
/// `x = 0` (no absorption) `R∞ = 1`; as `x → ∞`, `R∞ → 0`.
Spectrum kmReflectance(Spectrum koverS) {
  final out = Float32List(koverS.length);
  for (var i = 0; i < koverS.length; i++) {
    final x = koverS[i];
    out[i] = 1 + x - math.sqrt(x * x + 2 * x);
  }
  return out;
}

/// The Kubelka–Munk function: the inverse of [kmReflectance], recovering the
/// per-wavelength K/S ratio from a reflectance spectrum (design §3.1; AC-3).
///
/// Elementwise `K/S = (1 − R)² / (2R)`, one sample per input sample. Applying
/// this to the output of [kmReflectance] recovers the original K/S within
/// floating-point tolerance. `R` is a physical reflectance in `(0, 1]`; at
/// `R = 1` the result is `0` (no absorption).
Spectrum kmFunction(Spectrum reflectance) {
  final out = Float32List(reflectance.length);
  for (var i = 0; i < reflectance.length; i++) {
    final r = reflectance[i];
    final oneMinusR = 1 - r;
    out[i] = (oneMinusR * oneMinusR) / (2 * r);
  }
  return out;
}
