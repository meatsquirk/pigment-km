import '../grid.dart';

/// Resamples a spectrum from its native measurement grid onto the
/// [CanonicalGrid] (400–700 nm @ 10 nm = 31 bins) at ingest (design §2, §4.3;
/// AC-8).
///
/// [wavelengthsNm] are the native sample wavelengths in nanometres (ascending;
/// e.g. acrylic 380–730, oil 400–700) and [values] the reflectance (or K/S)
/// samples at those wavelengths, the same length. The result is the spectrum
/// linearly interpolated onto the canonical grid, so spectra measured on
/// different native grids become directly comparable. Resampling happens once,
/// at ingest — never at load time.
///
/// Shell stub (ITEST-2, Option A): **DATA-2** fills the body; until then this
/// throws the documented [UnimplementedError] so the AC-8 pending test fails on
/// its When for the right reason (the resampler is not built).
Spectrum resampleOntoCanonical(List<double> wavelengthsNm, List<double> values) =>
    throw UnimplementedError('resampleOntoCanonical — DATA-2');
