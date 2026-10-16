import 'dart:math' as math;

import '../types/colour_value.dart';

/// The colour-space conversion primitives shared by the colour backend
/// (design §2): sRGB ↔ OKLab/OKLCh (Ottosson) and sRGB ↔ CIE XYZ (D65).
///
/// The forward direction (linear sRGB → OKLCh, XYZ → linear sRGB, gamma encode)
/// is used by [spectrumToColour]; the inverse direction (OKLCh → linear sRGB,
/// linear sRGB → XYZ) is used by gamut mapping, which binary-searches chroma
/// down an OKLCh axis and re-encodes the result. Extracted here from
/// `spectrum_to_colour.dart` at COLOR-3 so both backends share one set of
/// matched matrices (no duplicated constants). The sRGB matrices are the
/// standard D65 pair; the OKLab matrices are Ottosson's forward constants and
/// their exact inverse.

/// The sRGB opto-electronic transfer function: one linear-light [channel] to its
/// gamma-encoded value in `[0,1]`, clamping out-of-gamut linear light first.
double encodeGamma(double channel) {
  final v = channel.clamp(0.0, 1.0).toDouble();
  if (v <= 0.0031308) {
    return 12.92 * v;
  }
  return 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;
}

/// Linear-light sRGB (D65) of an XYZ tristimulus value, by the standard
/// XYZ→linear-sRGB matrix. Channels may fall outside `[0,1]` when the colour is
/// out of gamut; the caller clamps only for the displayable sRGB.
({double r, double g, double b}) xyzToLinearSrgb(Xyz xyz) => (
      r: 3.2404542 * xyz.x - 1.5371385 * xyz.y - 0.4985314 * xyz.z,
      g: -0.9692660 * xyz.x + 1.8760108 * xyz.y + 0.0415560 * xyz.z,
      b: 0.0556434 * xyz.x - 0.2040259 * xyz.y + 1.0572252 * xyz.z,
    );

/// CIE XYZ (D65, `Y` normalized to 1) of a linear-light sRGB colour — the exact
/// inverse of [xyzToLinearSrgb], so a colour re-encoded after gamut mapping
/// carries an XYZ consistent with its sRGB and OKLCh.
Xyz linearSrgbToXyz(({double r, double g, double b}) c) => (
      x: 0.4124564 * c.r + 0.3575761 * c.g + 0.1804375 * c.b,
      y: 0.2126729 * c.r + 0.7151522 * c.g + 0.0721750 * c.b,
      z: 0.0193339 * c.r + 0.1191920 * c.g + 0.9503041 * c.b,
    );

/// OKLCh (Ottosson OKLab → polar) of a linear-light sRGB colour, matching the
/// acceptance suite's independent reference so the colour triple is consistent.
Oklch linearSrgbToOklch(({double r, double g, double b}) c) {
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

/// Linear-light sRGB of an OKLCh colour — the exact inverse of
/// [linearSrgbToOklch]. Channels may fall outside `[0,1]` when the OKLCh colour
/// is out of the sRGB gamut; the gamut mapper uses that to search chroma down.
({double r, double g, double b}) oklchToLinearSrgb(Oklch c) {
  final hRad = c.h * math.pi / 180.0;
  final okA = c.c * math.cos(hRad);
  final okB = c.c * math.sin(hRad);
  final lc = c.l + 0.3963377774 * okA + 0.2158037573 * okB;
  final mc = c.l - 0.1055613458 * okA - 0.0638541728 * okB;
  final sc = c.l - 0.0894841775 * okA - 1.2914855480 * okB;
  final l = lc * lc * lc;
  final m = mc * mc * mc;
  final s = sc * sc * sc;
  return (
    r: 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    g: -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    b: -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
  );
}

/// Sign-preserving cube root (`math.pow` returns NaN for a negative base), so
/// OKLab is well defined for the negative linear channels an out-of-gamut colour
/// produces.
double _cbrt(double x) =>
    x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();
