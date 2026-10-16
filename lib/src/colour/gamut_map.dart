import '../types/colour_value.dart';
import 'oklch.dart';

/// How far outside `[0,1]` a linear-light channel may stray and still count as
/// in gamut — a float tolerance so the binary search converges to the boundary
/// without a chroma that encodes to a channel pinned a hair past 0 or 1.
const double _gamutEps = 1e-7;

/// The number of bisection steps on the chroma axis. 40 halvings take an initial
/// chroma interval (< 1 in OKLCh) below 1e-12 — far tighter than the hue/
/// lightness tolerances the AC asserts.
const int _bisectSteps = 40;

/// Maps [colour] into the sRGB gamut without hard-clipping (design §2; AC-2).
///
/// The out-of-gamut signal is carried by the colour's OKLCh chroma, not its
/// sRGB channels (a predicted colour's displayable sRGB is already clamped). A
/// colour whose OKLCh encodes inside sRGB is returned unchanged. Otherwise the
/// chroma is reduced — at the colour's *fixed* OKLCh lightness and hue — by a
/// binary search down the chroma axis for the largest chroma that still encodes
/// in gamut (the Spectral.js / CSS Color 4 approach). The result is re-encoded
/// from that reduced-chroma OKLCh into a consistent (sRGB in `[0,1]`, XYZ,
/// OKLCh) triple, so hue and lightness are preserved and no channel is
/// hard-clipped at 0 or 1 to fake the match.
ColourValue gamutMap(ColourValue colour) {
  final target = colour.oklch;

  // Already in gamut at its full chroma → nothing to do.
  if (_inGamut(target.l, target.c, target.h)) {
    return colour;
  }

  // The largest chroma in [0, target.c] that still encodes inside sRGB. Chroma 0
  // (the neutral grey at this lightness) is in gamut, so `lo` always holds a
  // valid in-gamut chroma and `hi` an out-of-gamut one.
  var lo = 0.0;
  var hi = target.c;
  for (var i = 0; i < _bisectSteps; i++) {
    final mid = (lo + hi) / 2;
    if (_inGamut(target.l, mid, target.h)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }

  final linear = oklchToLinearSrgb((l: target.l, c: lo, h: target.h));
  return ColourValue(
    srgb: (
      r: encodeGamma(linear.r),
      g: encodeGamma(linear.g),
      b: encodeGamma(linear.b),
    ),
    xyz: linearSrgbToXyz(linear),
    oklch: (l: target.l, c: lo, h: target.h),
  );
}

/// Whether the OKLCh colour at lightness [l], chroma [c] and hue [h]° encodes to
/// linear-light sRGB inside `[0,1]` on every channel (within [_gamutEps]).
bool _inGamut(double l, double c, double h) {
  final lin = oklchToLinearSrgb((l: l, c: c, h: h));
  return _within01(lin.r) && _within01(lin.g) && _within01(lin.b);
}

bool _within01(double v) => v >= -_gamutEps && v <= 1 + _gamutEps;
