import 'dart:typed_data';

import '../grid.dart';

/// Resamples a spectrum from its native measurement grid onto the
/// [CanonicalGrid] (400–700 nm @ 10 nm = 31 bins) at ingest (design §2, §4.3;
/// AC-8).
///
/// [wavelengthsNm] are the native sample wavelengths in nanometres (strictly
/// ascending; e.g. acrylic 380–730, oil 400–700) and [values] the reflectance
/// (or K/S) samples at those wavelengths, the same length (≥ 2). The result is
/// the spectrum **linearly** interpolated onto the canonical grid, so spectra
/// measured on different native grids become directly comparable. Resampling
/// happens once, at ingest — never at load time.
///
/// Endpoint handling: a canonical wavelength outside the native range is held
/// flat at the nearest native endpoint (constant extrapolation). The datasets
/// in scope never need this — acrylic 380–730 brackets 400–700 and oil 400–700
/// coincides with it — but a conservative flat hold keeps a slightly short grid
/// well-defined rather than producing NaN or a wild extrapolation.
///
/// Throws [ArgumentError] when the two lists differ in length, when there are
/// fewer than two samples (nothing to interpolate between), or when the
/// wavelengths are not strictly ascending.
Spectrum resampleOntoCanonical(List<double> wavelengthsNm, List<double> values) {
  if (wavelengthsNm.length != values.length) {
    throw ArgumentError(
      'wavelengthsNm (${wavelengthsNm.length}) and values (${values.length}) '
      'must have equal length',
    );
  }
  if (wavelengthsNm.length < 2) {
    throw ArgumentError.value(
      wavelengthsNm.length,
      'wavelengthsNm.length',
      'resampling needs at least two native samples',
    );
  }
  for (var i = 1; i < wavelengthsNm.length; i++) {
    if (wavelengthsNm[i] <= wavelengthsNm[i - 1]) {
      throw ArgumentError.value(
        wavelengthsNm,
        'wavelengthsNm',
        'native wavelengths must be strictly ascending',
      );
    }
  }

  final out = Float32List(CanonicalGrid.bins);
  final first = wavelengthsNm.first;
  final last = wavelengthsNm.last;
  // The canonical grid is ascending, so the native cursor only advances.
  var j = 0;
  for (var i = 0; i < CanonicalGrid.bins; i++) {
    final nm = CanonicalGrid.wavelengthAt(i);
    if (nm <= first) {
      out[i] = values.first; // below the native range (or its first sample)
    } else if (nm >= last) {
      out[i] = values.last; // above the native range (or its last sample)
    } else {
      // Advance to the bracket [wavelengthsNm[j], wavelengthsNm[j + 1]) that
      // contains nm. j + 1 stays in range because nm < last.
      while (wavelengthsNm[j + 1] < nm) {
        j++;
      }
      final x0 = wavelengthsNm[j];
      final x1 = wavelengthsNm[j + 1];
      final t = (nm - x0) / (x1 - x0);
      out[i] = values[j] + t * (values[j + 1] - values[j]);
    }
  }
  return out;
}
