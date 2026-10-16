import '../grid.dart';

/// The Kubelka–Munk reflectance of a per-wavelength K/S ratio, opaque
/// (infinite-thickness) form (design §3.1, D-5; AC-3).
///
/// Elementwise `R∞ = 1 + x − sqrt(x² + 2x)` where `x = K/S`, over the whole
/// [CanonicalGrid]. [koverS] is the per-wavelength K/S spectrum; the result is
/// its reflectance spectrum.
///
/// Shell stub (ITEST-2, Option A): **KM-2** fills the body; until then this
/// throws the documented [UnimplementedError] so the AC-3 pending test fails on
/// its When for the right reason (the KM physics are not built).
Spectrum kmReflectance(Spectrum koverS) =>
    throw UnimplementedError('kmReflectance — KM-2');

/// The Kubelka–Munk function: the inverse of [kmReflectance], recovering the
/// per-wavelength K/S ratio from a reflectance spectrum (design §3.1; AC-3).
///
/// Elementwise `K/S = (1 − R)² / (2R)` over the [CanonicalGrid]. Applying this
/// to the output of [kmReflectance] recovers the original K/S within
/// floating-point tolerance.
///
/// Shell stub (ITEST-2, Option A): **KM-2** fills the body; until then this
/// throws the documented [UnimplementedError].
Spectrum kmFunction(Spectrum reflectance) =>
    throw UnimplementedError('kmFunction — KM-2');
