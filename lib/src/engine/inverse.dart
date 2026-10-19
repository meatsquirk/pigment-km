import 'dart:math' as math;

import '../tune/chroma_penalty.dart';
import '../types/colour_value.dart';
import '../types/medium.dart';
import '../types/mix_options.dart';
import '../types/pigment.dart';
import '../types/provenance.dart';
import '../types/recipe.dart';
import 'forward.dart';

/// The inverse solver (design §6.2) — SOLVER-2 the palette-constrained search,
/// SOLVER-3 the ranking (best-first by ΔE00, preferring fewer paints on a tie),
/// SOLVER-4 the honest out-of-gamut flag (an unreachable target's recipes are
/// flagged nearest approaches, never claimed matches), SOLVER-5 the cross-medium
/// partition (a single recipe never spans media), SOLVER-6 the tighter
/// per-subset optimizer (coarse grid then successive refinement) that matches a
/// reachable target well within the ΔE00 accuracy ceiling.
///
/// Given a [target] colour, the user's declared [palette] and the solve [opts],
/// returns candidate mixing [Recipe]s drawn **only** from that palette. SOLVER-7
/// adds the performance budget on top of this base.
///
/// Every candidate is formed by enumerating subsets of **one medium's** paints
/// (size 1 up to [MixOptions.maxPaints], capped at that medium's paint count) and
/// fitting the volume fractions of each subset to the target. Because the only
/// paints considered come from [palette], no paint outside it can ever appear in
/// a recipe (AC-16); and because each subset is drawn from a single medium's
/// group, no recipe ever spans media (AC-19, design §4.3) — its declared medium
/// is that group's medium.
///
/// The returned list is ranked by [_byCostThenFewerPaints] — best-first by ΔE00,
/// then (TUNE-2, when [MixOptions.chromaPenalty] is on) the more muted recipe on
/// a ΔE00 tie, then the simpler (fewer-paint) recipe (AC-15) — and truncated to
/// [MixOptions.topK] only after ranking, so the tie-break decides which recipes
/// survive the cut. An empty [palette] yields no recipes.
List<Recipe> solvePaletteConstrained(
  ColourValue target,
  List<Pigment> palette,
  MixOptions opts,
) {
  if (palette.isEmpty) {
    return const <Recipe>[];
  }

  // AC-19 / design §4.3 — the cross-medium hard constraint. A single recipe may
  // never span media, so the palette is partitioned by [Medium] and each
  // medium's paints are searched independently: every subset enumerated below is
  // drawn from one group, so each recipe's paints — and its declared medium —
  // come from exactly that medium. The groups' candidates are then pooled and
  // ranked together, so the global best-first order (AC-15) and the target-level
  // out-of-gamut verdict (AC-18) are unchanged; a cross-medium mixture is simply
  // never formed, even one that would land closer to the target. A single-medium
  // palette yields a single group — exactly the earlier per-palette search. The
  // groups keep the palette's medium-first-seen order, so ranking is
  // deterministic across runs.
  final byMedium = <Medium, List<Pigment>>{};
  for (final p in palette) {
    (byMedium[p.medium] ??= <Pigment>[]).add(p);
  }

  final candidates = <Recipe>[];
  byMedium.forEach((medium, group) {
    // SOLVER-7 (AC-20): the per-recipe paint count is capped so the subset
    // search stays within the performance budget even on a large palette.
    final maxK = _effectiveMaxPaints(group.length, opts.maxPaints);
    for (var k = 1; k <= maxK; k++) {
      for (final subset in _subsetsOfSize(group, k)) {
        candidates.add(_bestRecipeForSubset(subset, target, medium));
      }
    }
  });
  // AC-18 — the in/out-of-gamut verdict is a property of the *target*: whether
  // the best achievable ΔE00 over all candidates lands within the ceiling. It is
  // read from the true ΔE00 minimum, computed before ranking, so the TUNE-2
  // chroma tie-break (which may surface an equally-close but more muted recipe
  // ahead of the strict ΔE00 minimum) can never change whether a target is
  // reachable — it only reorders the returned recipes.
  final bestDelta =
      candidates.map((r) => r.deltaE00).reduce((a, b) => a < b ? a : b);

  // TUNE-2 (AC-22) — the ranking key. On a raw ΔE00 tie the lower-chroma, more
  // muted recipe is preferred when [MixOptions.chromaPenalty] is on; with it off
  // (λ = 0) the key is ΔE00 alone, so the penalty never leaks into the raw
  // ranking. The fewer-paint secondary key (AC-15) still decides a tie the
  // chroma penalty leaves equal (e.g. identical-reflectance mixes, which share
  // one colour and so one chroma).
  final lambda = opts.chromaPenalty ? naturalChromaPenalty : 0.0;
  candidates.sort((a, b) => _byCostThenFewerPaints(a, b, lambda));
  final ranked = candidates.length <= opts.topK
      ? candidates
      : candidates.sublist(0, opts.topK);

  // When the best achievable mix misses the ceiling, no mixture of this palette
  // can reach the target, so every returned recipe is an honest nearest approach
  // — each is flagged and relabelled so the engine never reports it as a match
  // (SI fixed intent). When the best is within the ceiling the target is in
  // gamut and the recipes pass unflagged, so a reachable target's recipes stay
  // `outOfGamut: false` even when a weaker alternative in the top-K exceeds the
  // ceiling on its own.
  if (bestDelta <= opts.gamutThreshold) {
    return ranked;
  }
  return <Recipe>[for (final r in ranked) _flaggedOutOfGamut(r)];
}

/// Re-stamps [recipe] as the honest nearest approach to an unreachable target:
/// the [Recipe.outOfGamut] flag set and the verdict relabelled so no caller can
/// read it as a claimed match (AC-18). Every other field — the fitted parts,
/// predicted colour, true ΔE00 distance and provenance — is carried through
/// unchanged, so the distance stays honest.
Recipe _flaggedOutOfGamut(Recipe recipe) => Recipe(
      medium: recipe.medium,
      parts: recipe.parts,
      colour: recipe.colour,
      deltaE00: recipe.deltaE00,
      provenance: recipe.provenance,
      outOfGamut: true,
      verdict:
          'out of gamut — nearest ΔE00 ${recipe.deltaE00.toStringAsFixed(2)}',
    );

/// Ranks two candidate recipes best-first by their chroma-penalized match cost
/// (TUNE-2, [chromaPenalizedCost] under [lambda]), then — on a cost tie — the
/// recipe using fewer paints wins (AC-15 "prefer fewer paints").
///
/// With `lambda == 0` the cost is ΔE00 alone, so this is the pure best-first-by-
/// ΔE00, fewer-paints-on-tie ranking: strictly monotonic in ΔE00 (two recipes
/// with even minutely different distances are ordered by distance, never
/// reshuffled by paint count), with the fewer-paint tie-break firing only on a
/// bit-equal ΔE00. Such a tie does occur: mixing identical-reflectance paints
/// yields the same measured colour at any ratio (the two-constant sum narrows to
/// the spectrum's Float32 precision in `mixTwoConstant`), so a 1-, 2- and
/// 3-paint recipe can land on an identical ΔE00 — and the simplest is preferred.
///
/// With `lambda > 0` (the chroma penalty on) a small `λ·C*` term is added to the
/// cost, so two recipes within numerical noise on ΔE00 are ordered lower-chroma
/// first, while the fewer-paint key still decides a pair the chroma term leaves
/// equal (identical-reflectance mixes share one colour, hence one chroma).
/// Making the key explicit guarantees the order independently of the sort's
/// stability and of the subset-enumeration order, rather than relying on either.
int _byCostThenFewerPaints(Recipe a, Recipe b, double lambda) {
  final byCost =
      chromaPenalizedCost(a, lambda).compareTo(chromaPenalizedCost(b, lambda));
  if (byCost != 0) {
    return byCost;
  }
  return a.parts.length.compareTo(b.parts.length);
}

/// SOLVER-7 (AC-20) — the performance guard. The subset search is combinatorial
/// in the number of paints allowed per recipe, so on a large palette the
/// effective per-recipe cap is lowered until the number of subsets enumerated
/// fits this budget; this keeps a ~15-paint top-3 solve within the SI budget
/// (~1–2 s) while leaving a small palette free to use the caller's full
/// [MixOptions.maxPaints]. It is an empirically-calibrated proxy for the solve
/// cost: at 1940 subsets (15 paints, ≤ 4 per recipe) the solve measures well
/// under the ceiling, while the next step up (4943 subsets, ≤ 5 per recipe)
/// overruns it — validated in the exclusive lane.
const int _subsetBudget = 2500;

/// The largest per-recipe paint count in `1 … [requested]` whose cumulative
/// subset count over a [groupSize]-paint medium group stays within
/// [_subsetBudget]. The binomial `C(groupSize, k)` is built incrementally and
/// the loop stops as soon as adding the size-`k` subsets would exceed the
/// budget, so it neither overflows nor over-counts. Returns at least 1 for any
/// non-empty group with [requested] ≥ 1 (a single-paint recipe is never over
/// budget for a realistic palette), so the solver always has candidates.
int _effectiveMaxPaints(int groupSize, int requested) {
  final limit = math.min(requested, groupSize);
  var subsets = 0;
  var choose = 1; // C(groupSize, 0)
  var maxK = 0;
  for (var k = 1; k <= limit; k++) {
    choose = choose * (groupSize - k + 1) ~/ k; // C(groupSize, k)
    if (subsets + choose > _subsetBudget) {
      break;
    }
    subsets += choose;
    maxK = k;
  }
  return maxK;
}

/// The coarse volume-fraction grid resolution: each paint's share starts as a
/// multiple of `1 / _gridSteps`. This grid only *locates* the basin; SOLVER-6's
/// successive refinement (below) then tightens the fit.
const int _gridSteps = 12;

/// SOLVER-6 — the successive-refinement passes applied after the coarse grid.
/// Each pass hill-climbs on a grid [_refineFactor]× finer than the one before,
/// so a reachable target is matched far more tightly than the `1 / _gridSteps`
/// grid alone, which can miss a near-pure tint by more than 5 ΔE00 (e.g. a
/// white+blue mix only 2.5% blue sits between the 1/12 grid node and pure white,
/// so the best coarse mix still lands over the 5 ceiling). The passes are
/// bounded so the solve cost stays modest — SOLVER-7 owns the performance budget.
const int _refineRounds = 3;
const int _refineFactor = 4;

/// The smallest ΔE00 improvement a refinement move must make to be accepted —
/// below this the fit has converged, so the hill-climb stops.
const double _refineEps = 1e-12;

/// Fits the best (lowest ΔE00) mixture of exactly the paints in [subset] to
/// [target]. A coarse simplex grid (every paint carrying a strictly positive
/// share, so pure and edge mixtures are left to the smaller subsets and a
/// k-paint recipe genuinely uses all k paints) locates the best grid node;
/// successive refinement (SOLVER-6) then hill-climbs on a shrinking step,
/// shifting volume between two paints at a time so the shares always sum to 1
/// and every share stays strictly positive, tightening the match.
Recipe _bestRecipeForSubset(
  List<Pigment> subset,
  ColourValue target,
  Medium medium,
) {
  final ids = <String>[for (final p in subset) p.id];
  final n = ids.length;

  // SOLVER-7 — precompute the subset's paint spectra and medium config once, so
  // the hundreds of grid + refinement evaluations below reuse them (and the
  // accumulation buffers) instead of re-resolving and re-validating per call.
  final forward = BoundForward(subset);

  ({double delta, ColourValue colour}) evaluate(List<double> shares) {
    final colour = forward.colourFor(shares);
    return (delta: deltaE2000Xyz(colour.xyz, target.xyz), colour: colour);
  }

  // Stage 1 — coarse grid: locate the best strictly-positive grid node.
  var best = const <double>[];
  var bestDelta = double.infinity;
  var bestColour = target;
  for (final shares in _compositions(_gridSteps, n)) {
    final frac = <double>[for (final s in shares) s / _gridSteps];
    final r = evaluate(frac);
    if (r.delta < bestDelta) {
      bestDelta = r.delta;
      best = frac;
      bestColour = r.colour;
    }
  }

  // Stage 2 — successive refinement: on each pass shrink the step and hill-climb
  // by moving `step` of volume from one paint to another, keeping Σ = 1 and
  // every share in (0, 1), until no single move improves the fit.
  var step = 1.0 / _gridSteps;
  for (var round = 0; round < _refineRounds; round++) {
    step /= _refineFactor;
    var improved = true;
    while (improved) {
      improved = false;
      for (var i = 0; i < n; i++) {
        for (var j = 0; j < n; j++) {
          if (i == j) {
            continue;
          }
          final trial = <double>[...best];
          trial[i] += step;
          trial[j] -= step;
          if (trial[j] <= 0 || trial[i] >= 1) {
            continue;
          }
          final r = evaluate(trial);
          if (r.delta < bestDelta - _refineEps) {
            bestDelta = r.delta;
            best = trial;
            bestColour = r.colour;
            improved = true;
          }
        }
      }
    }
  }

  final bestParts = <String, double>{
    for (var i = 0; i < n; i++) ids[i]: best[i],
  };
  return Recipe(
    medium: medium,
    parts: bestParts,
    colour: bestColour,
    deltaE00: bestDelta,
    provenance: _recipeProvenance(subset),
    outOfGamut: false,
    verdict: 'ΔE00 ${bestDelta.toStringAsFixed(2)}',
  );
}

/// The honesty tier of a recipe: no stronger than its weakest input. A mix that
/// draws on any [Provenance.estimated] paint is itself estimated; otherwise it is
/// a model [Provenance.calculated] result. (PROD-2/AC-24 refines the
/// measured-tube vs calculated distinction.)
Provenance _recipeProvenance(List<Pigment> subset) =>
    subset.any((p) => p.provenance == Provenance.estimated)
        ? Provenance.estimated
        : Provenance.calculated;

/// Every size-[k] subset of [palette], in input order.
Iterable<List<Pigment>> _subsetsOfSize(List<Pigment> palette, int k) sync* {
  final n = palette.length;
  final pick = List<int>.generate(k, (i) => i);
  while (true) {
    yield <Pigment>[for (final i in pick) palette[i]];
    var pos = k - 1;
    while (pos >= 0 && pick[pos] == n - k + pos) {
      pos--;
    }
    if (pos < 0) {
      return;
    }
    pick[pos]++;
    for (var j = pos + 1; j < k; j++) {
      pick[j] = pick[j - 1] + 1;
    }
  }
}

/// Every way to split [total] whole units into [parts] strictly-positive parts
/// (each ≥ 1), i.e. the compositions of [total] into [parts] bins. Used to walk
/// the simplex grid for a subset of that many paints.
Iterable<List<int>> _compositions(int total, int parts) sync* {
  if (parts == 1) {
    yield <int>[total];
    return;
  }
  for (var first = 1; first <= total - (parts - 1); first++) {
    for (final rest in _compositions(total - first, parts - 1)) {
      yield <int>[first, ...rest];
    }
  }
}

/// CIE standard illuminant D65, 2° observer, reference white (normalized Y = 1).
const Xyz _d65White = (x: 0.95047, y: 1.0, z: 1.08883);

/// CIELAB L*a*b* of an XYZ tristimulus value under D65 — the library's own
/// colour-difference maths (independent of the acceptance suite's reference).
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

/// CIEDE2000 colour difference between two XYZ values (via CIELAB / D65). The
/// solver's match metric (design §6.2, D-6).
double deltaE2000Xyz(Xyz a, Xyz b) {
  final labA = _xyzToLab(a);
  final labB = _xyzToLab(b);
  return deltaE2000Lab(labA.l, labA.a, labA.b, labB.l, labB.a, labB.b);
}

/// CIEDE2000 between two CIELAB triples (Sharma–Wu–Dalal formulation; kL = kC =
/// kH = 1). Public so tie-breaking (TUNE) and labelling (PROD) can reuse it.
double deltaE2000Lab(
  double l1,
  double a1,
  double b1,
  double l2,
  double a2,
  double b2,
) {
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
    if (b == 0 && ap == 0) {
      return 0;
    }
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
  final sL =
      1 + (0.015 * math.pow(lBarp - 50, 2)) / math.sqrt(20 + math.pow(lBarp - 50, 2));
  final sC = 1 + 0.045 * cBarp;
  final sH = 1 + 0.015 * cBarp * t;
  final rT = -math.sin(rad(2 * dTheta)) * rC;

  final termL = dLp / sL;
  final termC = dCp / sC;
  final termH = dHp / sH;
  return math.sqrt(
    termL * termL + termC * termC + termH * termH + rT * termC * termH,
  );
}
