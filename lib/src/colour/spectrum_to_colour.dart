import '../grid.dart';
import '../types/colour_value.dart';
import 'cmf_d65_weights.dart';
import 'oklch.dart';

/// Converts a reflectance [spectrum] on the [CanonicalGrid] to a [ColourValue]
/// under the D65 illuminant and the CIE 1931 2° standard observer (design §2,
/// §3.5; AC-1).
///
/// The backend weights the spectrum by the precomputed `x̄·D65`, `ȳ·D65`,
/// `z̄·D65` vectors ([xBarD65], [yBarD65], [zBarD65]) to tristimulus XYZ,
/// normalized by [yBarD65Sum] so a perfect diffuser yields the D65 white point
/// with `Y = 1`. XYZ is then encoded to displayable sRGB (standard D65 matrix +
/// gamma, clamped to `[0,1]`) and to OKLCh (from the *unclamped* linear sRGB, so
/// the chroma of an out-of-gamut colour is faithful for later gamut mapping).
/// All three consistent representations are returned. The sRGB/OKLab conversion
/// maths live in `oklch.dart`, shared with the gamut mapper.
ColourValue spectrumToColour(Spectrum spectrum) {
  CanonicalGrid.checkLength(spectrum);

  var x = 0.0;
  var y = 0.0;
  var z = 0.0;
  for (var i = 0; i < CanonicalGrid.bins; i++) {
    final r = spectrum[i];
    x += r * xBarD65[i];
    y += r * yBarD65[i];
    z += r * zBarD65[i];
  }
  final xyz = (x: x / yBarD65Sum, y: y / yBarD65Sum, z: z / yBarD65Sum);

  final linear = xyzToLinearSrgb(xyz);
  final srgb = (
    r: encodeGamma(linear.r),
    g: encodeGamma(linear.g),
    b: encodeGamma(linear.b),
  );
  final oklch = linearSrgbToOklch(linear);

  return ColourValue(srgb: srgb, xyz: xyz, oklch: oklch);
}
