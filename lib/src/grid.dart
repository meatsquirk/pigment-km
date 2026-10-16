import 'dart:typed_data';

/// A reflectance (or K/S) spectrum sampled on the [CanonicalGrid].
///
/// Always [CanonicalGrid.bins] samples long. Use [CanonicalGrid.checkLength] to
/// enforce the invariant at a boundary (ingest, construction) where the length
/// cannot otherwise be guaranteed.
typedef Spectrum = Float32List;

/// The canonical internal wavelength grid: 400–700 nm at 10 nm = 31 bins.
///
/// Every dataset is resampled onto this grid at ingest (design §2, §4.3), so
/// spectra from different media are directly comparable. The grid and the shared
/// CIE/D65 weights are *not* per-medium — only Saunderson k1,k2 and the drying
/// transform vary by medium (see [MediumConfig]).
abstract final class CanonicalGrid {
  /// First sampled wavelength, in nanometres.
  static const double start = 400;

  /// Last sampled wavelength, in nanometres.
  static const double end = 700;

  /// Spacing between samples, in nanometres.
  static const double step = 10;

  /// Number of samples on the grid: `(end - start) / step + 1 = 31`.
  static const int bins = 31;

  /// The wavelength (nm) at the given [bin], `0 <= bin < bins`.
  static double wavelengthAt(int bin) {
    if (bin < 0 || bin >= bins) {
      throw RangeError.range(bin, 0, bins - 1, 'bin');
    }
    return start + bin * step;
  }

  /// Returns [spectrum] unchanged if it has exactly [bins] samples; otherwise
  /// throws [ArgumentError]. Lets callers assert the grid invariant inline.
  static Spectrum checkLength(Spectrum spectrum) {
    if (spectrum.length != bins) {
      throw ArgumentError.value(
        spectrum.length,
        'spectrum.length',
        'a spectrum must have exactly $bins samples on the canonical grid',
      );
    }
    return spectrum;
  }
}

/// Element-wise equality for two spectra: same length and every sample equal.
bool spectraEqual(Spectrum a, Spectrum b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// An order-sensitive hash of a spectrum's samples, consistent with
/// [spectraEqual].
int spectrumHash(Spectrum s) => Object.hashAll(s);
