import 'dart:math' as math;

import 'package:pigment_km/pigment_km.dart';

/// Independent colour-difference reference maths for the acceptance suite.
///
/// These are the *test's own* yardstick — deliberately independent of the
/// library's internal colour maths — so an AC test that asserts "ΔE00 ≤ 1"
/// measures the library's output against a trusted reference, not against the
/// library's own metric. CIE standard illuminant D65, 10° observer (G-9 / D-14 —
/// the observer the measured paint data publishes its colours under).

/// The CIE D65 10° reference white (normalized Y = 1).
const Xyz _d65White = (x: 0.94811, y: 1.0, z: 1.07304);

/// The sRGB inverse electro-optical transfer function: one gamma-encoded
/// channel (0..1) to its linear-light value.
double _srgbToLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// CIE XYZ (D65, Y normalized to 1) of an sRGB colour — the independent
/// reference used to build acceptance targets and to check the engine's own
/// colour pipeline (AC-13/15/16/17). The standard linear-sRGB→XYZ D65 matrix.
Xyz srgbToXyz(Srgb c) {
  final r = _srgbToLinear(c.r);
  final g = _srgbToLinear(c.g);
  final b = _srgbToLinear(c.b);
  return (
    x: 0.4123907993 * r + 0.3575843394 * g + 0.1804807884 * b,
    y: 0.2126390059 * r + 0.7151686788 * g + 0.0721923154 * b,
    z: 0.0193308187 * r + 0.1191947798 * g + 0.9505321522 * b,
  );
}

/// OKLCh (Ottosson OKLab → polar) of an sRGB colour — the independent reference
/// for chroma/hue assertions (AC-13 desaturation) and target construction.
Oklch srgbToOklch(Srgb c) {
  final r = _srgbToLinear(c.r);
  final g = _srgbToLinear(c.g);
  final b = _srgbToLinear(c.b);
  final l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
  final m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
  final s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;
  final lc = math.pow(l, 1.0 / 3.0).toDouble();
  final mc = math.pow(m, 1.0 / 3.0).toDouble();
  final sc = math.pow(s, 1.0 / 3.0).toDouble();
  final okL = 0.2104542553 * lc + 0.7936177850 * mc - 0.0040720468 * sc;
  final okA = 1.9779984951 * lc - 2.4285922050 * mc + 0.4505937099 * sc;
  final okB = 0.0259040371 * lc + 0.7827717662 * mc - 0.8086757660 * sc;
  final chroma = math.sqrt(okA * okA + okB * okB);
  var hue = math.atan2(okB, okA) * 180.0 / math.pi;
  if (hue < 0) hue += 360;
  return (l: okL, c: chroma, h: hue);
}

/// Linear-light sRGB of an OKLCh colour — the independent inverse of the OKLab
/// maths in [srgbToOklch] (Ottosson's inverse constants). Channels fall outside
/// `[0,1]` exactly when the OKLCh colour is out of the sRGB gamut, so a gamut
/// mapper's *reported* OKLCh can be checked for being GENUINELY in gamut here —
/// unlike a mapper's displayable sRGB, which the gamma encoder always clamps and
/// which therefore cannot reveal a hard-clipped (out-of-gamut) channel.
({double r, double g, double b}) oklchToLinearSrgb(Oklch c) {
  final hRad = c.h * math.pi / 180.0;
  final a = c.c * math.cos(hRad);
  final b = c.c * math.sin(hRad);
  final lc = c.l + 0.3963377774 * a + 0.2158037573 * b;
  final mc = c.l - 0.1055613458 * a - 0.0638541728 * b;
  final sc = c.l - 0.0894841775 * a - 1.2914855480 * b;
  final l = lc * lc * lc;
  final m = mc * mc * mc;
  final s = sc * sc * sc;
  return (
    r: 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    g: -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    b: -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
  );
}

/// Builds a consistent [ColourValue] (sRGB, XYZ, OKLCh of the same colour) from
/// an sRGB triple via the independent reference, so acceptance targets carry all
/// three representations the way the engine's own output does.
ColourValue colourFromSrgb(Srgb srgb) =>
    ColourValue(srgb: srgb, xyz: srgbToXyz(srgb), oklch: srgbToOklch(srgb));

/// CIE XYZ (D65 10°, Y normalized to 1) of a CIELAB L*a*b* triple — the exact
/// inverse of [xyzToLab]. Used to turn a dataset's published L*a*b* into the XYZ
/// the acceptance tests compare against (AC-7 Golden/RIT round-trip yardstick).
Xyz labToXyz(double l, double a, double b) {
  const d = 6.0 / 29.0;
  double finv(double t) => t > d ? t * t * t : 3 * d * d * (t - 4.0 / 29.0);
  final fy = (l + 16) / 116;
  final fx = fy + a / 500;
  final fz = fy - b / 200;
  return (
    x: _d65White.x * finv(fx),
    y: _d65White.y * finv(fy),
    z: _d65White.z * finv(fz),
  );
}

/// The sRGB opto-electronic transfer function: one linear-light channel to its
/// gamma-encoded value, clamped to the display gamut (the inverse of
/// [_srgbToLinear]).
double _linearToSrgb(double c) {
  final v = c <= 0.0031308 ? 12.92 * c : 1.055 * math.pow(c, 1 / 2.4) - 0.055;
  return v.clamp(0.0, 1.0).toDouble();
}

/// Displayable sRGB of an XYZ value (standard D65 XYZ→linear-sRGB matrix, the
/// inverse of [srgbToXyz], then the sRGB transfer function, clamped to the
/// display gamut). For a strongly chromatic (out-of-gamut) colour the clamp
/// makes sRGB only a display stand-in — the gamut-truthful representation is XYZ.
Srgb xyzToSrgb(Xyz xyz) {
  final r = 3.2409699419 * xyz.x - 1.5373831776 * xyz.y - 0.4986107603 * xyz.z;
  final g = -0.9692436363 * xyz.x + 1.8759675015 * xyz.y + 0.0415550574 * xyz.z;
  final b = 0.0556300797 * xyz.x - 0.2039769589 * xyz.y + 1.0569715142 * xyz.z;
  return (r: _linearToSrgb(r), g: _linearToSrgb(g), b: _linearToSrgb(b));
}

/// Builds a consistent [ColourValue] from a published CIELAB L*a*b* triple: XYZ
/// is the exact [labToXyz] (the value colour-difference maths use), sRGB/OKLCh
/// are the display/gamut stand-ins derived from it. Acceptance tests assert on
/// the XYZ; the other two are carried for parity with the engine's own triples.
ColourValue colourFromLab(double l, double a, double b) {
  final xyz = labToXyz(l, a, b);
  final srgb = xyzToSrgb(xyz);
  return ColourValue(srgb: srgb, xyz: xyz, oklch: srgbToOklch(srgb));
}

/// The absolute circular hue difference in degrees (0..180).
double hueDiffDeg(double a, double b) {
  var d = (a - b).abs() % 360;
  if (d > 180) d = 360 - d;
  return d;
}

/// CIELAB L*a*b* of an XYZ tristimulus value under D65.
({double l, double a, double b}) xyzToLab(Xyz xyz) {
  double f(double t) {
    const d = 6.0 / 29.0;
    return t > d * d * d ? math.pow(t, 1.0 / 3.0).toDouble() : t / (3 * d * d) + 4.0 / 29.0;
  }

  final fx = f(xyz.x / _d65White.x);
  final fy = f(xyz.y / _d65White.y);
  final fz = f(xyz.z / _d65White.z);
  return (l: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz));
}

/// CIEDE2000 colour difference between two XYZ values (via CIELAB/D65).
///
/// Implements the Sharma–Wu–Dalal formulation (the standard CIEDE2000). Used by
/// the AC tests that assert a ΔE00 threshold against a published/measured colour.
double deltaE00(Xyz xyz1, Xyz xyz2) {
  final lab1 = xyzToLab(xyz1);
  final lab2 = xyzToLab(xyz2);
  return deltaE00Lab(lab1.l, lab1.a, lab1.b, lab2.l, lab2.a, lab2.b);
}

/// CIEDE2000 between two CIELAB triples.
double deltaE00Lab(
  double l1,
  double a1,
  double b1,
  double l2,
  double a2,
  double b2,
) {
  const kL = 1.0, kC = 1.0, kH = 1.0;
  double rad(double d) => d * math.pi / 180.0;
  double deg(double r) => r * 180.0 / math.pi;

  final c1 = math.sqrt(a1 * a1 + b1 * b1);
  final c2 = math.sqrt(a2 * a2 + b2 * b2);
  final cBar = (c1 + c2) / 2.0;
  final cBar7 = math.pow(cBar, 7).toDouble();
  final g = 0.5 * (1 - math.sqrt(cBar7 / (cBar7 + math.pow(25, 7))));

  final a1p = (1 + g) * a1;
  final a2p = (1 + g) * a2;
  final c1p = math.sqrt(a1p * a1p + b1 * b1);
  final c2p = math.sqrt(a2p * a2p + b2 * b2);

  double hp(double b, double ap) {
    if (b == 0 && ap == 0) return 0;
    final h = deg(math.atan2(b, ap));
    return h >= 0 ? h : h + 360;
  }

  final h1p = hp(b1, a1p);
  final h2p = hp(b2, a2p);

  final dLp = l2 - l1;
  final dCp = c2p - c1p;

  double dhp;
  if (c1p * c2p == 0) {
    dhp = 0;
  } else if ((h2p - h1p).abs() <= 180) {
    dhp = h2p - h1p;
  } else if (h2p - h1p > 180) {
    dhp = h2p - h1p - 360;
  } else {
    dhp = h2p - h1p + 360;
  }
  final dHp = 2 * math.sqrt(c1p * c2p) * math.sin(rad(dhp) / 2);

  final lBarp = (l1 + l2) / 2;
  final cBarp = (c1p + c2p) / 2;

  double hBarp;
  if (c1p * c2p == 0) {
    hBarp = h1p + h2p;
  } else if ((h1p - h2p).abs() <= 180) {
    hBarp = (h1p + h2p) / 2;
  } else if (h1p + h2p < 360) {
    hBarp = (h1p + h2p + 360) / 2;
  } else {
    hBarp = (h1p + h2p - 360) / 2;
  }

  final t = 1 -
      0.17 * math.cos(rad(hBarp - 30)) +
      0.24 * math.cos(rad(2 * hBarp)) +
      0.32 * math.cos(rad(3 * hBarp + 6)) -
      0.20 * math.cos(rad(4 * hBarp - 63));

  final dTheta = 30 * math.exp(-math.pow((hBarp - 275) / 25, 2).toDouble());
  final cBarp7 = math.pow(cBarp, 7).toDouble();
  final rC = 2 * math.sqrt(cBarp7 / (cBarp7 + math.pow(25, 7)));
  final sL = 1 + (0.015 * math.pow(lBarp - 50, 2)) / math.sqrt(20 + math.pow(lBarp - 50, 2));
  final sC = 1 + 0.045 * cBarp;
  final sH = 1 + 0.015 * cBarp * t;
  final rT = -math.sin(rad(2 * dTheta)) * rC;

  final termL = dLp / (kL * sL);
  final termC = dCp / (kC * sC);
  final termH = dHp / (kH * sH);
  return math.sqrt(
    termL * termL + termC * termC + termH * termH + rT * termC * termH,
  );
}
