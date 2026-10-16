import 'dart:math' as math;

import 'package:pigment_km/pigment_km.dart';

/// Independent colour-difference reference maths for the acceptance suite.
///
/// These are the *test's own* yardstick — deliberately independent of the
/// library's internal colour maths — so an AC test that asserts "ΔE00 ≤ 1"
/// measures the library's output against a trusted reference, not against the
/// library's own metric. CIE standard illuminant D65, 2° observer.

/// The CIE D65 2° reference white (normalized Y = 1).
const Xyz _d65White = (x: 0.95047, y: 1.0, z: 1.08883);

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
