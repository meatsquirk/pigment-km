import 'dart:math' as math;

import '../grid.dart';
import '../types/colour_value.dart';
import 'cmf_d65_weights.dart';

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
/// All three consistent representations are returned.
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

  final linear = _xyzToLinearSrgb(xyz);
  final srgb = (
    r: _encodeGamma(linear.r),
    g: _encodeGamma(linear.g),
    b: _encodeGamma(linear.b),
  );
  final oklch = _linearSrgbToOklch(linear);

  return ColourValue(srgb: srgb, xyz: xyz, oklch: oklch);
}

/// Linear-light sRGB (D65) of an XYZ tristimulus value, by the standard
/// XYZ→linear-sRGB matrix. Channels may fall outside `[0,1]` when the colour is
/// out of gamut; the caller clamps only for the displayable sRGB.
({double r, double g, double b}) _xyzToLinearSrgb(Xyz xyz) => (
      r: 3.2404542 * xyz.x - 1.5371385 * xyz.y - 0.4985314 * xyz.z,
      g: -0.9692660 * xyz.x + 1.8760108 * xyz.y + 0.0415560 * xyz.z,
      b: 0.0556434 * xyz.x - 0.2040259 * xyz.y + 1.0572252 * xyz.z,
    );

/// The sRGB opto-electronic transfer function: one linear-light [channel] to its
/// gamma-encoded value in `[0,1]`, clamping out-of-gamut linear light first.
double _encodeGamma(double channel) {
  final v = channel.clamp(0.0, 1.0).toDouble();
  if (v <= 0.0031308) {
    return 12.92 * v;
  }
  return 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;
}

/// OKLCh (Ottosson OKLab → polar) of a linear-light sRGB colour, matching the
/// acceptance suite's independent reference so the triple is consistent.
Oklch _linearSrgbToOklch(({double r, double g, double b}) c) {
  final l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
  final m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
  final s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;
  final lc = _cbrt(l);
  final mc = _cbrt(m);
  final sc = _cbrt(s);
  final okL = 0.2104542553 * lc + 0.7936177850 * mc - 0.0040720468 * sc;
  final okA = 1.9779984951 * lc - 2.4285922050 * mc + 0.4505937099 * sc;
  final okB = 0.0259040371 * lc + 0.7827717662 * mc - 0.8086757660 * sc;
  final chroma = math.sqrt(okA * okA + okB * okB);
  var hue = math.atan2(okB, okA) * 180.0 / math.pi;
  if (hue < 0) {
    hue += 360;
  }
  return (l: okL, c: chroma, h: hue);
}

/// Sign-preserving cube root (`math.pow` returns NaN for a negative base), so
/// OKLab is well defined for the negative linear channels an out-of-gamut colour
/// produces.
double _cbrt(double x) =>
    x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();
