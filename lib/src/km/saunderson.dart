import 'dart:typed_data';

import '../grid.dart';
import '../types/medium.dart';

/// The documented default Saunderson surface-correction constants per medium
/// (design §3.2, §4.3).
///
/// `k1` is the external (specular) surface-reflection coefficient and `k2` the
/// internal-reflection coefficient at the film–air boundary. They differ by
/// medium because oil's cured binder has a higher refractive index than an
/// acrylic film, so more light is reflected at its surface (a larger `k1`).
///
/// These are **documented defaults**, not the authoritative values: the real
/// per-medium `k1,k2` are confirmed from each dataset's README (gate G-5). Until
/// then the AC-4 round-trip test asserts *structure* — the correction round-trips
/// and the two media's constants differ — not these literals.
const double _acrylicK1 = 0.04;
const double _acrylicK2 = 0.6;
const double _oilK1 = 0.05;
const double _oilK2 = 0.6;

/// The per-medium Saunderson surface-correction constants (design §3.2, §4.3).
///
/// Returns the [MediumConfig] — the `k1`, `k2` surface-reflection constants and
/// the drying transform — for [medium]. Acrylic and oil carry **distinct**
/// constants (oil's refractive-index boundary differs from acrylic's), so the
/// same internal reflectance corrects to different measured reflectance per
/// medium (AC-4 control). The authoritative values come from each dataset's
/// README (G-5); until then this uses the documented defaults above.
MediumConfig configForMedium(Medium medium) => switch (medium) {
      Medium.acrylic =>
        const MediumConfig(medium: Medium.acrylic, k1: _acrylicK1, k2: _acrylicK2),
      Medium.oil =>
        const MediumConfig(medium: Medium.oil, k1: _oilK1, k2: _oilK2),
    };

/// Applies the Saunderson correction, mapping an [internal] reflectance spectrum
/// to the measured (surface-corrected) reflectance using [config]'s `k1`, `k2`
/// (design §3.2; AC-4).
///
/// Elementwise `R_m = k1 + (1−k1)(1−k2)·R_i / (1 − k2·R_i)`, one sample per input
/// sample. The `k1` term is the specular surface reflection added on top; the
/// fraction is the internally diffused light that escapes the film. The exact
/// inverse is [saundersonToInternal].
Spectrum saundersonToMeasured(Spectrum internal, MediumConfig config) {
  final k1 = config.k1;
  final k2 = config.k2;
  final a = (1 - k1) * (1 - k2);
  final out = Float32List(internal.length);
  for (var i = 0; i < internal.length; i++) {
    final ri = internal[i];
    out[i] = k1 + a * ri / (1 - k2 * ri);
  }
  return out;
}

/// The inverse Saunderson correction: maps a [measured] reflectance spectrum
/// back to the internal reflectance using [config]'s `k1`, `k2` (design §3.2).
///
/// Elementwise `R_i = (R_m − k1) / ((1−k1)(1−k2) + k2·(R_m − k1))` — the algebraic
/// inverse of [saundersonToMeasured], so the two round-trip within floating-point
/// tolerance over the physical reflectance range (AC-4).
Spectrum saundersonToInternal(Spectrum measured, MediumConfig config) {
  final k1 = config.k1;
  final k2 = config.k2;
  final a = (1 - k1) * (1 - k2);
  final out = Float32List(measured.length);
  for (var i = 0; i < measured.length; i++) {
    final diff = measured[i] - k1;
    out[i] = diff / (a + k2 * diff);
  }
  return out;
}
