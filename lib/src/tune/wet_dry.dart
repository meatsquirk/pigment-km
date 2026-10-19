import 'dart:math' as math;

import '../colour/oklch.dart';
import '../types/colour_value.dart';
import '../types/medium.dart';
import '../types/recipe.dart';

/// The wet→dry state transform (design §7 lever 3, D-12).
///
/// A solved recipe predicts a mixture's *wet* colour — the state the forward
/// model and the solver work in. Paint shifts as it dries (an acrylic film's
/// milky binder clarifies, so the colour darkens and shifts), so the same
/// recipe is **re-rendered** in its dry state here without re-solving: the parts
/// and the ΔE00 match distance are the mixture's, unchanged, and only the
/// predicted colour moves by the medium's documented drying offset
/// ([WetDryTransform], carried on each [MediumConfig]).
///
/// This is why `forward`/`inverse` stay option-free in their colour maths (gate
/// G-2): the wet/dry choice is a post-prediction display state read through the
/// engine from `MixOptions.wet`, not a parameter of the physics. The offset is
/// documented in CIE L*C*h — the perceptual axes the drying shift is described
/// on — so [driedColour] converts the wet XYZ to L*C*h, adds the deltas, and
/// rebuilds a consistent sRGB/XYZ/OKLCh triple exactly as the colour backend
/// does (shared maths in `oklch.dart`, no duplicated matrices).

/// CIE standard illuminant D65, 10° observer, reference white (Y normalized to
/// 1) — the same white the colour backend and the solver's ΔE00 maths use
/// (kept in lock-step with `inverse.dart`'s `_d65White`; G-9/D-14).
const Xyz _d65White = (x: 0.94811, y: 1.0, z: 1.07304);

/// Re-renders [recipe] in its dry state by applying the medium's drying
/// [transform] to its predicted colour. Every other field — the fitted parts,
/// the ΔE00 match distance, the provenance, the out-of-gamut flag and the
/// verdict — is carried through unchanged, so the toggle is a state transform,
/// never a re-solve (AC-23). The identity transform returns [recipe] itself.
Recipe toDryState(Recipe recipe, WetDryTransform transform) {
  if (transform == WetDryTransform.none) {
    return recipe;
  }
  return Recipe(
    medium: recipe.medium,
    parts: recipe.parts,
    colour: driedColour(recipe.colour, transform),
    deltaE00: recipe.deltaE00,
    provenance: recipe.provenance,
    outOfGamut: recipe.outOfGamut,
    verdict: recipe.verdict,
  );
}

/// Applies the wet→dry [transform]'s CIE L*C*h deltas to the wet colour [wet],
/// returning the dry [ColourValue] with consistent sRGB, XYZ and OKLCh.
///
/// The wet XYZ is converted to CIELAB then to L*C*h; the lightness, chroma and
/// hue deltas are added (chroma clamped at 0, hue wrapped to `[0, 360)`); the
/// result is converted back to CIELAB, to XYZ, and then — reusing the colour
/// backend's own matrices — to displayable sRGB and to OKLCh. Because L* alone
/// sets Y, a negative lightness delta darkens the colour (lowers Y) regardless
/// of the chroma and hue deltas. The identity transform returns [wet] unchanged.
ColourValue driedColour(ColourValue wet, WetDryTransform transform) {
  if (transform == WetDryTransform.none) {
    return wet;
  }
  final lab = _xyzToLab(wet.xyz);
  final chroma = math.sqrt(lab.a * lab.a + lab.b * lab.b);
  var hue = math.atan2(lab.b, lab.a) * 180.0 / math.pi;
  if (hue < 0) {
    hue += 360;
  }

  final dryL = lab.l + transform.lightnessDelta;
  final dryC = math.max(0.0, chroma + transform.chromaDelta);
  // Dart's `%` with a positive divisor already yields a value in `[0, 360)`, so
  // a negative or past-360° rotation wraps correctly without a further guard.
  final dryH = (hue + transform.hueDeltaDeg) % 360;

  final hRad = dryH * math.pi / 180.0;
  final xyz = _labToXyz(dryL, dryC * math.cos(hRad), dryC * math.sin(hRad));

  final linear = xyzToLinearSrgb(xyz);
  final srgb = (
    r: encodeGamma(linear.r),
    g: encodeGamma(linear.g),
    b: encodeGamma(linear.b),
  );
  return ColourValue(srgb: srgb, xyz: xyz, oklch: linearSrgbToOklch(linear));
}

/// CIELAB L*a*b* of an XYZ tristimulus value under D65.
({double l, double a, double b}) _xyzToLab(Xyz xyz) {
  double f(double t) {
    const delta = 6.0 / 29.0;
    if (t > delta * delta * delta) {
      return math.pow(t, 1.0 / 3.0).toDouble();
    }
    return t / (3 * delta * delta) + 4.0 / 29.0;
  }

  final fx = f(xyz.x / _d65White.x);
  final fy = f(xyz.y / _d65White.y);
  final fz = f(xyz.z / _d65White.z);
  return (l: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz));
}

/// XYZ (D65, Y normalized to 1) of a CIELAB L*a*b* triple — the exact inverse of
/// [_xyzToLab], so a colour converted to L*C*h and back carries an XYZ
/// consistent with its sRGB and OKLCh.
Xyz _labToXyz(double l, double a, double b) {
  double fInv(double t) {
    const delta = 6.0 / 29.0;
    if (t > delta) {
      return t * t * t;
    }
    return 3 * delta * delta * (t - 4.0 / 29.0);
  }

  final fy = (l + 16) / 116;
  final fx = fy + a / 500;
  final fz = fy - b / 200;
  return (
    x: _d65White.x * fInv(fx),
    y: _d65White.y * fInv(fy),
    z: _d65White.z * fInv(fz),
  );
}
