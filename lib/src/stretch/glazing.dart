import 'dart:math' as math;
import 'dart:typed_data';

import '../grid.dart';
import '../km/mixing.dart';
import '../km/reflectance.dart';

/// The reflectance of a glaze of finite film thickness over a ground of known
/// reflectance — the finite-thickness Kubelka–Munk layering equation
/// (design §3.4; AC-26, STRETCH / S6).
///
/// The opaque body reflectance ([kmReflectance]) is the infinite-thickness
/// limit: it hides whatever is beneath it. A real glaze is a *finite* film, so
/// some of the ground still shows through. This function is the two-constant KM
/// solution for a single homogeneous layer of optical thickness `Smix·X` laid
/// over a background of reflectance `Rg` (design §3.4):
///
/// ```text
/// a = 1 + K/S
/// b = sqrt(a² − 1) = sqrt((K/S)² + 2·K/S)
/// R = (1 − Rg·(a − b·coth(b·S·X))) / (a − Rg + b·coth(b·S·X))
/// ```
///
/// evaluated per wavelength over the [CanonicalGrid]. [glaze] is the layer's
/// two-constant description (`Kmix`, `Smix` — typically the output of
/// [mixTwoConstant]); [thickness] is the film thickness `X` in the reciprocal
/// unit of `S`, so `S·X` is the dimensionless optical thickness; [ground] is the
/// substrate reflectance spectrum `Rg`.
///
/// Boundary behaviour (each is a control the acceptance test pins):
///
/// * **Opaque limit** — as `X → ∞` the `coth` term → 1 and `R →
///   a − b = kmReflectance(K/S)`: a thick enough glaze reproduces the opaque
///   body reflectance and the ground no longer shows. (A thickness large enough
///   that `b·S·X` saturates returns the opaque form exactly.)
/// * **Vanishing limit** — as `X → 0` the `coth` term → ∞ and `R → Rg`: an
///   infinitely thin film is just the bare ground.
/// * **Self-consistency** — when `Rg` already equals the opaque reflectance
///   `a − b`, `R = a − b` at *every* thickness: layering a glaze over a ground
///   of its own opaque colour changes nothing.
///
/// Reusing the opaque form (ignoring [thickness] and [ground]) would break the
/// vanishing limit and the ground's influence — this is what AC-26 rejects.
///
/// [thickness] must be finite and strictly positive; [glaze] spectra and
/// [ground] must each have [CanonicalGrid.bins] samples. Otherwise throws
/// [ArgumentError].
Spectrum glazedReflectance({
  required KmMix glaze,
  required double thickness,
  required Spectrum ground,
}) {
  if (!thickness.isFinite || thickness <= 0) {
    throw ArgumentError.value(
      thickness,
      'thickness',
      'the film thickness must be finite and strictly positive',
    );
  }
  CanonicalGrid.checkLength(glaze.k);
  CanonicalGrid.checkLength(glaze.s);
  CanonicalGrid.checkLength(ground);

  const bins = CanonicalGrid.bins;
  // Above this optical thickness, coth(b·S·X) is 1 to within double precision;
  // clamping here both returns the exact opaque limit and avoids overflow in
  // exp(2·b·S·X). exp(60) ≈ 1.1e26, comfortably inside double range.
  const cothSaturation = 30.0;
  // Below this |b|, the glaze barely absorbs (K/S ≈ 0); b·coth(b·S·X) has the
  // finite limit 1/(S·X), so take it directly rather than dividing by ~0.
  const bEpsilon = 1e-9;

  final out = Float32List(bins);
  for (var i = 0; i < bins; i++) {
    final k = glaze.k[i];
    final s = glaze.s[i];
    final rg = ground[i];

    final x = k / s; // K/S
    final a = 1 + x;
    final b = math.sqrt(x * x + 2 * x); // sqrt(a² − 1)

    final double bCoth; // b·coth(b·S·X)
    if (b < bEpsilon) {
      bCoth = 1 / (s * thickness);
    } else {
      final y = b * s * thickness;
      if (y >= cothSaturation) {
        bCoth = b; // coth(y) → 1
      } else {
        final e2y = math.exp(2 * y);
        bCoth = b * (e2y + 1) / (e2y - 1); // b·coth(y)
      }
    }

    out[i] = (1 - rg * (a - bCoth)) / (a - rg + bCoth);
  }
  return out;
}
