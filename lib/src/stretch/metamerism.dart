import 'dart:math' as math;

import '../colour/cmf_d65_weights.dart';
import '../engine/inverse.dart' show deltaE2000Lab;
import '../grid.dart';

/// The multi-illuminant metamerism assessment of one candidate reflectance
/// against a target (design §9; AC-27, STRETCH / S6).
///
/// A metameric match is one that matches its target under a reference
/// illuminant but *degrades* under another — the two spectra share a colour
/// under one light and part under a different one. This assessment renders both
/// the [candidate] and the target under a reference and a test illuminant and
/// reports how much the match degrades between them.
class MetamerismAssessment {
  const MetamerismAssessment({
    required this.deltaE00Reference,
    required this.deltaE00Test,
    required this.index,
    required this.illuminantFragile,
  });

  /// ΔE00 between the candidate and the target under the reference illuminant.
  final double deltaE00Reference;

  /// ΔE00 between the candidate and the target under the test illuminant.
  final double deltaE00Test;

  /// The metamerism index: how much the match *degrades* from the reference to
  /// the test illuminant, `max(0, deltaE00Test − deltaE00Reference)`. A spectral
  /// (non-metameric) match — one whose candidate reproduces the target spectrum
  /// — holds under every illuminant and scores `0`; a match that only holds
  /// under the reference light scores the full test-illuminant difference.
  final double index;

  /// Whether the match is illuminant-fragile: its [index] exceeds the
  /// fragility threshold. The engine warns on such a match.
  final bool illuminantFragile;
}

/// The default ΔE00 of metameric degradation above which a match is called
/// illuminant-fragile (design §9). A one-ΔE00 drift under the test light is the
/// just-about-noticeable boundary at which a match stops being dependable.
const double defaultMetamerismFragileThreshold = 1.0;

/// Assesses the illuminant robustness of a [candidate] reflectance against a
/// [target], across a [referenceIlluminant] and a [testIlluminant]
/// (design §9; AC-27).
///
/// Both the candidate and the target are rendered to a colour under each
/// illuminant and the ΔE00 of the match is measured under both; the returned
/// [MetamerismAssessment.index] is how much worse the match is under the test
/// light than under the reference, and [MetamerismAssessment.illuminantFragile]
/// is `true` when that degradation exceeds [fragileThreshold] — the warning the
/// spec requires. Computing the index needs *both* illuminants: a candidate
/// that only metamerises the target (matches under the reference but not the
/// test light) is indistinguishable from a spectral match under the reference
/// alone, and separates only once the test light is applied.
///
/// **Rendering under an illuminant.** The colour pipeline (`spectrum_to_colour`)
/// folds the CIE 1964 10° observer and the D65 SPD into one weight vector per
/// channel ([xBarD65] = `x̄₁₀·S_D65`, …). This function reuses those weights and
/// reweights them by each illuminant's spectral power relative to the supplied
/// [referenceIlluminant]: the per-bin factor `S_illum / S_reference` turns
/// `x̄₁₀·S_D65` into `x̄₁₀·S_D65·(S_illum/S_reference)`. For the reference render
/// the factor is `1`, so it is exactly the D65 observer product the main
/// pipeline uses; for the test render it is the observer product reweighted to
/// the test light. Each render is then adapted to its own illuminant's white
/// (von-Kries-style: Lab is taken relative to the perfect-diffuser tristimulus
/// under that illuminant), so a perfectly colour-constant match scores `0` and
/// the index measures genuine spectral divergence, not a global cast.
///
/// **Caveat (design §9, placeholder SPDs).** The reweighting is exact when the
/// supplied [referenceIlluminant] is the D65 SPD the CMF weights are baked
/// under; the acceptance fixture's reference and warm studio SPDs are
/// acknowledged daylight-locus / Planckian placeholders (their exact tables are
/// finalized if a measured studio SPD lands), so — like the finite-thickness
/// glaze's assumed film — this is a predictive mechanism over placeholder
/// lights, not fit to a measured studio illuminant.
///
/// Throws [ArgumentError] if any spectrum is off the canonical grid, if either
/// illuminant has a non-finite or non-positive sample, or if [fragileThreshold]
/// is negative or non-finite.
MetamerismAssessment assessMetamerism({
  required Spectrum target,
  required Spectrum candidate,
  required Spectrum referenceIlluminant,
  required Spectrum testIlluminant,
  double fragileThreshold = defaultMetamerismFragileThreshold,
}) {
  CanonicalGrid.checkLength(target);
  CanonicalGrid.checkLength(candidate);
  CanonicalGrid.checkLength(referenceIlluminant);
  CanonicalGrid.checkLength(testIlluminant);
  _checkIlluminant(referenceIlluminant, 'referenceIlluminant');
  _checkIlluminant(testIlluminant, 'testIlluminant');
  if (!fragileThreshold.isFinite || fragileThreshold < 0) {
    throw ArgumentError.value(
      fragileThreshold,
      'fragileThreshold',
      'must be a finite, non-negative ΔE00',
    );
  }

  final refTarget = _labUnder(target, referenceIlluminant, referenceIlluminant);
  final refCand =
      _labUnder(candidate, referenceIlluminant, referenceIlluminant);
  final testTarget = _labUnder(target, testIlluminant, referenceIlluminant);
  final testCand = _labUnder(candidate, testIlluminant, referenceIlluminant);

  final dRef = deltaE2000Lab(
      refTarget.l, refTarget.a, refTarget.b, refCand.l, refCand.a, refCand.b);
  final dTest = deltaE2000Lab(testTarget.l, testTarget.a, testTarget.b,
      testCand.l, testCand.a, testCand.b);
  final index = math.max(0.0, dTest - dRef);

  return MetamerismAssessment(
    deltaE00Reference: dRef,
    deltaE00Test: dTest,
    index: index,
    illuminantFragile: index > fragileThreshold,
  );
}

/// The CIELAB L\*a\*b\* of [reflectance] under [illum], with the observer×D65
/// weights reweighted by `illum / reference` (see [assessMetamerism]) and Lab
/// taken relative to the illuminant's own perfect-diffuser white (adaptation).
({double l, double a, double b}) _labUnder(
  Spectrum reflectance,
  Spectrum illum,
  Spectrum reference,
) {
  var x = 0.0;
  var y = 0.0;
  var z = 0.0;
  var xw = 0.0;
  var yw = 0.0;
  var zw = 0.0;
  for (var i = 0; i < CanonicalGrid.bins; i++) {
    final m = illum[i] / reference[i];
    final wx = xBarD65[i] * m;
    final wy = yBarD65[i] * m;
    final wz = zBarD65[i] * m;
    final r = reflectance[i];
    x += r * wx;
    y += r * wy;
    z += r * wz;
    xw += wx;
    yw += wy;
    zw += wz;
  }
  // Lab relative to the illuminant's own white (von-Kries adaptation): a
  // perfect diffuser is achromatic under every illuminant, so the difference
  // reported is spectral divergence, not a shared cast.
  double f(double t) {
    const delta = 6.0 / 29.0;
    if (t > delta * delta * delta) {
      return math.pow(t, 1.0 / 3.0).toDouble();
    }
    return t / (3 * delta * delta) + 4.0 / 29.0;
  }

  final fx = f(x / xw);
  final fy = f(y / yw);
  final fz = f(z / zw);
  return (l: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz));
}

void _checkIlluminant(Spectrum illum, String name) {
  for (final v in illum) {
    if (!v.isFinite || v <= 0) {
      throw ArgumentError.value(
        v,
        name,
        'illuminant SPD samples must be finite and positive',
      );
    }
  }
}
