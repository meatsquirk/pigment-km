import 'dart:math' as math;

import '../types/colour_value.dart';
import '../types/medium.dart';
import '../types/mix_options.dart';
import '../types/pigment.dart';
import '../types/provenance.dart';
import '../types/recipe.dart';
import 'forward.dart';

/// The inverse solver (design §6.2) — SOLVER-2: the palette-constrained search.
///
/// Given a [target] colour, the user's declared [palette] and the solve [opts],
/// returns candidate mixing [Recipe]s drawn **only** from that palette. Later
/// SOLVER phases build on this base: SOLVER-3 adds the prefer-fewer tie-break on
/// top of the ΔE00 ordering here, SOLVER-4 the honest out-of-gamut flag, SOLVER-5
/// the explicit per-medium partition, SOLVER-6 a tighter optimizer, SOLVER-7 the
/// performance budget.
///
/// Every candidate is formed by enumerating subsets of the palette (size 1 up to
/// [MixOptions.maxPaints], capped at the palette size) and fitting the volume
/// fractions of each subset to the target. Because the only paints considered
/// come from [palette], no paint outside it can ever appear in a recipe (AC-16).
/// The subsets are drawn from a single-medium palette — the cross-medium
/// partition and its guarantee are SOLVER-5's; here the recipe medium is the
/// palette's medium.
///
/// The returned list is ordered best-first by ΔE00 and truncated to
/// [MixOptions.topK]. An empty [palette] yields no recipes.
List<Recipe> solvePaletteConstrained(
  ColourValue target,
  List<Pigment> palette,
  MixOptions opts,
) {
  if (palette.isEmpty) {
    return const <Recipe>[];
  }
  final byId = <String, Pigment>{for (final p in palette) p.id: p};
  Pigment resolve(String id) => byId[id]!;
  final medium = palette.first.medium;
  final maxK = math.min(opts.maxPaints, palette.length);

  final candidates = <Recipe>[];
  for (var k = 1; k <= maxK; k++) {
    for (final subset in _subsetsOfSize(palette, k)) {
      candidates.add(_bestRecipeForSubset(subset, target, medium, resolve));
    }
  }
  candidates.sort((a, b) => a.deltaE00.compareTo(b.deltaE00));
  if (candidates.length <= opts.topK) {
    return candidates;
  }
  return candidates.sublist(0, opts.topK);
}

/// The volume-fraction grid resolution: each paint's share is a multiple of
/// `1 / _gridSteps`. A basic optimizer (SOLVER-2); SOLVER-6 tightens accuracy.
const int _gridSteps = 12;

/// Fits the best (lowest ΔE00) mixture of exactly the paints in [subset] to
/// [target], searching volume fractions on the simplex grid where every paint in
/// the subset carries a strictly positive share (pure and edge mixtures are left
/// to the smaller subsets, so a k-paint recipe genuinely uses all k paints).
Recipe _bestRecipeForSubset(
  List<Pigment> subset,
  ColourValue target,
  Medium medium,
  PigmentResolver resolve,
) {
  final ids = <String>[for (final p in subset) p.id];
  var bestDelta = double.infinity;
  var bestParts = const <String, double>{};
  var bestColour = target;
  for (final shares in _compositions(_gridSteps, subset.length)) {
    final parts = <String, double>{
      for (var i = 0; i < ids.length; i++) ids[i]: shares[i] / _gridSteps,
    };
    final colour = forwardColour(parts, resolve);
    final delta = deltaE2000Xyz(colour.xyz, target.xyz);
    if (delta < bestDelta) {
      bestDelta = delta;
      bestParts = parts;
      bestColour = colour;
    }
  }
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
