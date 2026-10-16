import '../grid.dart';
import '../types/medium.dart';

/// The per-medium Saunderson surface-correction constants (design §3.2, §4.3).
///
/// Returns the [MediumConfig] — the `k1`, `k2` surface-reflection constants and
/// the drying transform — for [medium]. Acrylic and oil carry **distinct**
/// constants (oil's refractive-index boundary differs from acrylic's), so the
/// same internal reflectance corrects to different measured reflectance per
/// medium (AC-4 control). The authoritative values come from each dataset's
/// README (G-5); until then KM-3 uses the documented defaults.
///
/// Shell stub (ITEST-2, Option A): **KM-3** fills the body; until then this
/// throws the documented [UnimplementedError] so the AC-4 pending test fails on
/// its Given for the right reason (the per-medium constants are not built).
MediumConfig configForMedium(Medium medium) =>
    throw UnimplementedError('configForMedium — KM-3');

/// Applies the Saunderson correction, mapping an [internal] reflectance spectrum
/// to the measured (surface-corrected) reflectance using [config]'s `k1`, `k2`
/// (design §3.2; AC-4).
///
/// Shell stub (ITEST-2, Option A): **KM-3** fills the body; until then this
/// throws the documented [UnimplementedError].
Spectrum saundersonToMeasured(Spectrum internal, MediumConfig config) =>
    throw UnimplementedError('saundersonToMeasured — KM-3');

/// The inverse Saunderson correction: maps a [measured] reflectance spectrum
/// back to the internal reflectance using [config]'s `k1`, `k2` (design §3.2).
/// Round-trips with [saundersonToMeasured] within tolerance (AC-4).
///
/// Shell stub (ITEST-2, Option A): **KM-3** fills the body; until then this
/// throws the documented [UnimplementedError].
Spectrum saundersonToInternal(Spectrum measured, MediumConfig config) =>
    throw UnimplementedError('saundersonToInternal — KM-3');
