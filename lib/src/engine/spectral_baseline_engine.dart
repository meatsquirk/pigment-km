import 'dart:math' as math;
import 'dart:typed_data';

import '../colour/spectrum_to_colour.dart';
import '../data/pigment_table.dart';
import '../grid.dart';
import '../km/reflectance.dart';
import '../km/saunderson.dart';
import '../types/colour_value.dart';
import '../types/medium.dart';
import '../types/mix_options.dart';
import '../types/pigment.dart';
import '../types/recipe.dart';
import 'forward.dart' show normalizeParts;
import 'inverse.dart' show deltaE2000Xyz;
import 'mixing_engine.dart';
import 'provenance.dart';

/// The single-constant spectral baseline engine (design §8 S0/S5).
///
/// It implements the same [MixingEngine] interface as [CustomKmEngine], so the
/// two are drop-in interchangeable and the A/B harness ([ABHarness]) can report
/// each one's ΔE00 on the same swatch set with no caller change (AC-25, SI D3).
/// It is the deliberately simpler reference model the measured-pigment engine is
/// benchmarked against — not the product engine.
///
/// **What makes it single-constant.** The two-constant [CustomKmEngine] carries
/// each paint's absorption `K` and scattering `S` separately and mixes them
/// independently (`Kmix = Σ v·K`, `Smix = Σ v·S`) before forming `K/S`. This
/// baseline instead reduces every paint to one quantity — its per-wavelength
/// absorption-to-scattering ratio `K/S` — and mixes *those* ratios linearly
/// (`(K/S)mix = Σ v·(K/S)`), the classic single-constant Kubelka–Munk law (design
/// §3.3). The two laws agree only when all paints share one scattering spectrum;
/// where scattering differs they diverge, which is exactly the fidelity gap the
/// A/B comparison surfaces. From the mixed `K/S` the pipeline is identical to the
/// two-constant engine's: opaque Kubelka–Munk reflectance ([kmReflectance]) →
/// Saunderson surface correction ([saundersonToMeasured]) → colour
/// ([spectrumToColour]).
///
/// The baseline predicts in the paint's native wet state only (the wet/dry
/// toggle, [MixOptions.wet], is a display lever of the product engine and is not
/// part of the reference model).
class SpectralBaselineEngine implements MixingEngine {
  const SpectralBaselineEngine();

  @override
  ColourValue forward(Map<String, double> mix) =>
      spectrumToColour(reflectanceOf(mix));

  @override
  Spectrum reflectanceOf(Map<String, double> mix) {
    final weights = normalizeParts(mix);
    final paints = <Pigment>[for (final id in weights.keys) _resolve(id)];
    final bound = _BoundSingleConstant(paints);
    return bound.reflectanceFor(<double>[for (final v in weights.values) v]);
  }

  @override
  List<Recipe> inverse(
    ColourValue target,
    List<Pigment> palette,
    MixOptions opts,
  ) {
    if (palette.isEmpty) {
      return const <Recipe>[];
    }

    // The cross-medium constraint (design §4.3): the palette is partitioned by
    // medium and each group is searched independently, so no recipe ever spans
    // media — exactly as the two-constant solver does it (AC-19). Groups keep
    // the palette's first-seen medium order so ranking is deterministic.
    final byMedium = <Medium, List<Pigment>>{};
    for (final p in palette) {
      (byMedium[p.medium] ??= <Pigment>[]).add(p);
    }

    final candidates = <Recipe>[];
    byMedium.forEach((medium, group) {
      final maxK = math.min(opts.maxPaints, group.length);
      for (var k = 1; k <= maxK; k++) {
        for (final subset in _subsetsOfSize(group, k)) {
          candidates.add(_bestRecipeForSubset(subset, target, medium));
        }
      }
    });

    // The in/out-of-gamut verdict is a property of the target: whether the best
    // achievable ΔE00 over all candidates lands within the ceiling. Read from
    // the true minimum, before ranking, so ordering can never change it.
    final bestDelta =
        candidates.map((r) => r.deltaE00).reduce((a, b) => a < b ? a : b);

    // Best-first by ΔE00, then the simpler (fewer-paint) recipe on a tie — the
    // same public ranking shape as [CustomKmEngine.inverse] (the baseline omits
    // the TUNE chroma penalty, which is a product-engine lever, not a reference
    // one). The key is explicit so the order does not depend on sort stability
    // or enumeration order.
    candidates.sort((a, b) {
      final byDelta = a.deltaE00.compareTo(b.deltaE00);
      if (byDelta != 0) {
        return byDelta;
      }
      return a.parts.length.compareTo(b.parts.length);
    });
    final ranked = candidates.length <= opts.topK
        ? candidates
        : candidates.sublist(0, opts.topK);

    // When the best achievable mix misses the ceiling the target is unreachable,
    // so every returned recipe is an honest nearest approach — flagged and
    // relabelled so it is never read as a match. Within the ceiling the recipes
    // pass unflagged.
    if (bestDelta <= opts.gamutThreshold) {
      return ranked;
    }
    return <Recipe>[for (final r in ranked) _flaggedOutOfGamut(r)];
  }

  /// Resolves a paint [id] to its [Pigment] by searching the loaded pigment
  /// table of each medium (design §4). Throws [ArgumentError] if no medium's
  /// table holds the id.
  static Pigment _resolve(String id) {
    for (final medium in Medium.values) {
      final pigment = PigmentTable.load(medium).byId(id);
      if (pigment != null) {
        return pigment;
      }
    }
    throw ArgumentError.value(
      id,
      'id',
      'no paint with this id in any medium table',
    );
  }
}

/// Re-stamps [recipe] as the honest nearest approach to an unreachable target:
/// [Recipe.outOfGamut] set and the verdict relabelled so no caller reads it as a
/// claimed match (AC-18). Every other field — the fitted parts, predicted
/// colour, true ΔE00 and provenance — carries through unchanged.
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

/// The coarse volume-fraction grid resolution: each paint's share starts as a
/// multiple of `1 / _gridSteps`, locating the basin the refinement then tightens.
const int _gridSteps = 12;

/// Successive-refinement passes after the coarse grid: each hill-climbs on a grid
/// [_refineFactor]× finer than the one before, so a reachable target is matched
/// far more tightly than the coarse grid alone. Bounded so the solve stays cheap.
const int _refineRounds = 3;
const int _refineFactor = 4;

/// The smallest ΔE00 improvement a refinement move must make to be accepted;
/// below this the fit has converged and the hill-climb stops.
const double _refineEps = 1e-12;

/// Fits the best (lowest ΔE00) single-constant mixture of exactly the paints in
/// [subset] to [target]. A coarse strictly-positive simplex grid locates the
/// best node, then successive refinement shifts volume between two paints at a
/// time — keeping Σ = 1 and every share in (0, 1) — until no single move
/// improves the fit.
Recipe _bestRecipeForSubset(
  List<Pigment> subset,
  ColourValue target,
  Medium medium,
) {
  final ids = <String>[for (final p in subset) p.id];
  final n = ids.length;
  final bound = _BoundSingleConstant(subset);

  double deltaFor(List<double> shares) =>
      deltaE2000Xyz(bound.colourFor(shares).xyz, target.xyz);

  // Stage 1 — coarse grid: locate the best strictly-positive grid node.
  var best = const <double>[];
  var bestDelta = double.infinity;
  for (final comp in _compositions(_gridSteps, n)) {
    final frac = <double>[for (final s in comp) s / _gridSteps];
    final delta = deltaFor(frac);
    if (delta < bestDelta) {
      bestDelta = delta;
      best = frac;
    }
  }

  // Stage 2 — successive refinement: shrink the step each pass and hill-climb by
  // moving `step` of volume from one paint to another until no move improves.
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
          final delta = deltaFor(trial);
          if (delta < bestDelta - _refineEps) {
            bestDelta = delta;
            best = trial;
            improved = true;
          }
        }
      }
    }
  }

  return Recipe(
    medium: medium,
    parts: <String, double>{for (var i = 0; i < n; i++) ids[i]: best[i]},
    colour: bound.colourFor(best),
    deltaE00: bestDelta,
    provenance: recipeProvenance(subset),
    outOfGamut: false,
    verdict: 'ΔE00 ${bestDelta.toStringAsFixed(2)}',
  );
}

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
/// (each ≥ 1): the compositions of [total] into [parts] bins, walking the
/// simplex grid for a subset of that many paints.
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

/// A single-medium set of paints reduced to the single-constant model and bound
/// once, so an inverse solve evaluates many share vectors over the same paints
/// without re-reducing their spectra each time.
///
/// Each paint is reduced in the constructor to its per-wavelength `K/S` ratio;
/// [reflectanceFor] mixes those ratios by volume share (`(K/S)mix = Σ w·(K/S)`),
/// then takes the mix through opaque Kubelka–Munk reflectance and the medium's
/// Saunderson correction. [colourFor] converts that to a [ColourValue].
class _BoundSingleConstant {
  _BoundSingleConstant._(this._n, this._koverS, this._config);

  /// Binds to [paints]. All paints must share one medium (a single mixture never
  /// spans media — see [MixingEngine]); otherwise throws [ArgumentError]. Callers
  /// pass a non-empty, single-medium list (a normalized mixture, or one medium
  /// group's subset).
  factory _BoundSingleConstant(List<Pigment> paints) {
    final medium = paints.first.medium;
    final koverS = <Spectrum>[];
    for (final p in paints) {
      if (p.medium != medium) {
        throw ArgumentError.value(
          paints,
          'paints',
          'a single mixture must not span media '
              '(${medium.name} vs ${p.medium.name})',
        );
      }
      CanonicalGrid.checkLength(p.k);
      CanonicalGrid.checkLength(p.s);
      final ks = Float32List(CanonicalGrid.bins);
      for (var b = 0; b < CanonicalGrid.bins; b++) {
        ks[b] = p.k[b] / p.s[b];
      }
      koverS.add(ks);
    }
    return _BoundSingleConstant._(
      paints.length,
      koverS,
      configForMedium(medium),
    );
  }

  final int _n;
  final List<Spectrum> _koverS;
  final MediumConfig _config;

  /// The measured reflectance of the bound paints mixed at volume [shares] (one
  /// share per bound paint, in bind order). [shares] is normalized to sum 1
  /// (design §5; AC-14), so any positive scaling of the same ratio yields the
  /// same reflectance.
  Spectrum reflectanceFor(List<double> shares) {
    const bins = CanonicalGrid.bins;
    var total = 0.0;
    for (var i = 0; i < _n; i++) {
      total += shares[i];
    }
    final acc = Float64List(bins);
    for (var i = 0; i < _n; i++) {
      final w = shares[i] / total;
      final ks = _koverS[i];
      for (var b = 0; b < bins; b++) {
        acc[b] += w * ks[b];
      }
    }
    final koverS = Float32List(bins);
    for (var b = 0; b < bins; b++) {
      koverS[b] = acc[b];
    }
    final internal = kmReflectance(koverS);
    return saundersonToMeasured(internal, _config);
  }

  /// The predicted colour of the bound paints mixed at volume [shares].
  ColourValue colourFor(List<double> shares) =>
      spectrumToColour(reflectanceFor(shares));
}
