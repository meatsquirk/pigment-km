import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';
// SOLVER-7 reaches the internal performance helper and the reference forward
// evaluator directly, to pin that the bound evaluator is bit-identical.
import 'package:pigment_km/src/engine/forward.dart' show BoundForward, forwardColour;
import 'package:test/test.dart';

/// ΔE00 between two L*=50, chroma-30 colours at the given hue angles (degrees),
/// so a test can pin a specific pair of hues onto the CIEDE2000 hue branches.
double _deltaAtHues(double h1, double h2) {
  (double, double) ab(double hue) {
    final r = hue * math.pi / 180.0;
    return (30 * math.cos(r), 30 * math.sin(r));
  }

  final c1 = ab(h1);
  final c2 = ab(h2);
  return deltaE2000Lab(50, c1.$1, c1.$2, 50, c2.$1, c2.$2);
}

const _target = ColourValue(
  srgb: (r: 0.1, g: 0.2, b: 0.3),
  xyz: (x: 0.4, y: 0.5, z: 0.6),
  oklch: (l: 0.7, c: 0.1, h: 120.0),
);

void main() {
  test('CustomKmEngine implements MixingEngine; forward and inverse are live '
      '(FORWARD-2, SOLVER-2)', () {
    const engine = CustomKmEngine();
    expect(engine, isA<MixingEngine>());
    // The forward model is now implemented (FORWARD-2): it resolves the paint id
    // against the loaded medium tables and runs the pipeline, so it does NOT
    // throw UnimplementedError on a real paint.
    const whiteId = 'acrylic.titanium_white';
    final colour = engine.forward(const {whiteId: 1.0});
    expect(colour, isA<ColourValue>());
    final reflectance = engine.reflectanceOf(const {whiteId: 1.0});
    expect(reflectance, hasLength(CanonicalGrid.bins));
    // forward == spectrumToColour(reflectanceOf): the two share one pipeline.
    expect(engine.forward(const {whiteId: 1.0}), colour);
    // The inverse solver is live (SOLVER-2): it returns recipes rather than
    // throwing. An empty palette has no recipes to return.
    expect(engine.inverse(_target, const [], const MixOptions()), isEmpty);
  });

  group('CustomKmEngine.inverse — palette-constrained search (SOLVER-2)', () {
    const engine = CustomKmEngine();
    final palette = PigmentTable.load(Medium.acrylic).pigments;
    final target = engine.forward(const {
      'acrylic.titanium_white': 0.7,
      'acrylic.phthalo_blue': 0.3,
    });

    test('returns palette-only recipes, parts summing to 1, ordered by ΔE00, '
        'capped at topK', () {
      const opts = MixOptions(topK: 4);
      final recipes = engine.inverse(target, palette, opts);
      expect(recipes, isNotEmpty);
      expect(recipes.length, lessThanOrEqualTo(opts.topK));
      final paletteIds = palette.map((p) => p.id).toSet();
      for (final r in recipes) {
        expect(r.parts, isNotEmpty);
        expect(r.parts.keys, everyElement(isIn(paletteIds)));
        expect(r.parts.values, everyElement(greaterThan(0.0)));
        expect(r.parts.values.fold<double>(0, (a, b) => a + b),
            closeTo(1.0, 1e-9));
        expect(r.medium, Medium.acrylic);
        expect(r.outOfGamut, isFalse);
        expect(r.verdict, contains('ΔE00'));
      }
      for (var i = 1; i < recipes.length; i++) {
        expect(recipes[i].deltaE00,
            greaterThanOrEqualTo(recipes[i - 1].deltaE00));
      }
      // A reachable target (a real white+blue mix) is matched closely.
      expect(recipes.first.deltaE00, lessThan(2.0));
    });

    test('maxPaints caps the subset size the search explores', () {
      // With maxPaints 1 only single-paint recipes form (one per palette paint).
      final recipes =
          engine.inverse(target, palette, const MixOptions(maxPaints: 1));
      expect(recipes, hasLength(palette.length));
      for (final r in recipes) {
        expect(r.parts, hasLength(1));
      }
    });

    test('a recipe is estimated when any paint is, else calculated', () {
      // The synthetic palette is all estimated → estimated recipes.
      final estimated = engine.inverse(target, palette, const MixOptions());
      expect(estimated, isNotEmpty);
      expect(estimated, everyElement(predicate<Recipe>(
          (r) => r.provenance == Provenance.estimated)));

      // A palette of calculated-provenance paints → calculated recipes.
      final calc = [
        for (final p in palette)
          Pigment(
            id: p.id,
            name: p.name,
            pigmentIndex: p.pigmentIndex,
            medium: p.medium,
            k: p.k,
            s: p.s,
            opacity: p.opacity,
            provenance: Provenance.calculated,
            sourceRef: p.sourceRef,
          ),
      ];
      final calcRecipes = engine.inverse(target, calc, const MixOptions());
      expect(calcRecipes, isNotEmpty);
      expect(calcRecipes, everyElement(predicate<Recipe>(
          (r) => r.provenance == Provenance.calculated)));
    });
  });

  group('CustomKmEngine.inverse — ranking / prefer fewer paints (SOLVER-3)', () {
    const engine = CustomKmEngine();

    // Six identical-reflectance paints (same K, same S): every mixture predicts
    // the same measured colour at any ratio and any paint count — the two-
    // constant sum narrows to the spectrum's Float32 precision — so all subsets
    // tie EXACTLY on ΔE00. C(6,1..4) = 56 candidates (maxPaints defaults to 4) is
    // above Dart's 32-element insertion-sort threshold, so List.sort runs the
    // *unstable* quicksort: only the explicit prefer-fewer secondary key makes
    // the paint-count ranking non-decreasing (a ΔE00-only sort reshuffles the
    // bit-equal candidates). This both covers the byDelta == 0 branch and proves
    // the tie-break changes behaviour.
    final k = Float32List.fromList(
        [for (var i = 0; i < CanonicalGrid.bins; i++) 0.07 + 0.015 * i]);
    final s =
        Float32List.fromList(List<double>.filled(CanonicalGrid.bins, 0.4));
    Pigment twin(String id) => Pigment(
          id: id,
          name: id,
          pigmentIndex: 'PX',
          medium: Medium.acrylic,
          k: k,
          s: s,
          opacity: 0.5,
          provenance: Provenance.estimated,
          sourceRef: 'synthetic:$id',
        );
    final twins = [
      for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) twin(id),
    ];
    const target = ColourValue(
      srgb: (r: 0.5, g: 0.5, b: 0.5),
      xyz: (x: 0.2, y: 0.2, z: 0.2),
      oklch: (l: 0.5, c: 0.0, h: 0.0),
    );

    test('on an exact ΔE00 tie the fewer-paint recipe ranks first', () {
      final recipes =
          engine.inverse(target, twins, const MixOptions(topK: 100));

      expect(recipes, hasLength(56));
      final tied = recipes.first.deltaE00;
      expect(recipes, everyElement(predicate<Recipe>((r) => r.deltaE00 == tied)),
          reason: 'identical-reflectance mixes tie exactly on ΔE00');
      final counts = [for (final r in recipes) r.parts.length];
      expect(counts.first, 1);
      expect(counts.last, 4);
      for (var i = 1; i < counts.length; i++) {
        expect(counts[i], greaterThanOrEqualTo(counts[i - 1]),
            reason: 'paint count is non-decreasing down the ranking on a tie');
      }
    });

    test('truncation to topK keeps the tie-break winners (fewer paints survive '
        'the cut)', () {
      // topK < the number of subsets: because the tie-break runs BEFORE
      // truncation, the survivors are the simplest recipes, not an arbitrary
      // slice of equal-ΔE00 candidates.
      final recipes = engine.inverse(target, twins, const MixOptions(topK: 6));
      expect(recipes, hasLength(6));
      // The six survivors are exactly the single-paint recipes.
      expect(recipes, everyElement(predicate<Recipe>((r) => r.parts.length == 1)),
          reason: 'the simplest recipes outrank equal-ΔE00 heavier ones and so '
              'survive the topK cut');
    });
  });

  group('CustomKmEngine.inverse — out-of-gamut honesty (SOLVER-4)', () {
    const engine = CustomKmEngine();
    final acrylic = PigmentTable.load(Medium.acrylic).pigments; // white, blue, red
    const whiteId = 'acrylic.titanium_white';
    const blueId = 'acrylic.phthalo_blue';
    final whiteBlue =
        acrylic.where((p) => p.id == whiteId || p.id == blueId).toList();

    test('a palette with no green flags a saturated green target out-of-gamut and '
        'never claims a match', () {
      // GIVEN the acrylic palette (white, blue, red — no green primary) and a
      // vivid pure-green target no mixture of it can reach within the ceiling.
      const green = ColourValue(
        srgb: (r: 0.0, g: 1.0, b: 0.0),
        xyz: (x: 0.3576, y: 0.7152, z: 0.1192),
        oklch: (l: 0.866, c: 0.295, h: 142.5),
      );

      // WHEN the solver returns its recipes.
      final recipes = engine.inverse(green, acrylic, const MixOptions());
      expect(recipes, isNotEmpty);

      // THEN every returned recipe is the honest nearest approach: flagged
      // out-of-gamut, carrying a true ΔE00 beyond the ceiling, and relabelled so
      // it reads as out of gamut rather than a match. Rejects an engine that
      // returns the nearest mix unflagged or keeps a match-style verdict.
      const ceiling = 5.0;
      for (final r in recipes) {
        expect(r.outOfGamut, isTrue);
        expect(r.deltaE00, greaterThan(ceiling));
        expect(r.verdict, contains('out of gamut'));
        expect(r.verdict, contains(r.deltaE00.toStringAsFixed(2)));
      }
    });

    test('a reachable target leaves the whole recipe set unflagged, even a weak '
        'alternative beyond the ceiling', () {
      // GIVEN the target is exactly pure white's own colour, so pure white
      // matches it (ΔE00 ≈ 0) — the target is in gamut.
      final target = engine.forward(const {whiteId: 1.0});
      const opts = MixOptions(maxPaints: 2, topK: 3);
      final recipes = engine.inverse(target, whiteBlue, opts);

      // The full candidate set is returned (3 subsets ≤ topK), so the pure-blue
      // recipe — a far, beyond-ceiling alternative — is present.
      expect(recipes, hasLength(3));
      final best = recipes.first;
      expect(best.parts.keys, orderedEquals([whiteId]));
      expect(best.deltaE00, lessThanOrEqualTo(opts.gamutThreshold));
      final pureBlue = recipes.firstWhere(
          (r) => r.parts.length == 1 && r.parts.containsKey(blueId));
      expect(pureBlue.deltaE00, greaterThan(opts.gamutThreshold),
          reason: 'the pure-blue alternative must itself miss the ceiling');

      // THEN because the *best* recipe is in gamut, the target is reachable, so
      // no recipe is flagged — not even the weak pure-blue one. Rejects a
      // per-recipe flag that would mark `pureBlue` out-of-gamut on its own ΔE00.
      expect(recipes, everyElement(predicate<Recipe>((r) => !r.outOfGamut)),
          reason: 'out-of-gamut is a target-level verdict, not per recipe');
      expect(best.verdict, isNot(contains('out of gamut')));
    });
  });

  group('CustomKmEngine.inverse — cross-medium partition (SOLVER-5)', () {
    const engine = CustomKmEngine();
    final acrylic = PigmentTable.load(Medium.acrylic).pigments;
    final oil = PigmentTable.load(Medium.oil).pigments;
    final mixedPalette = <Pigment>[...acrylic, ...oil];
    final idToMedium = <String, Medium>{
      for (final p in mixedPalette) p.id: p.medium,
    };

    test('every recipe from a mixed-media palette uses one medium only', () {
      // GIVEN a palette spanning both acrylic and oil paints — the partition
      // must split it in two and search each group alone.
      expect(mixedPalette.map((p) => p.medium).toSet(),
          containsAll(<Medium>{Medium.acrylic, Medium.oil}));
      const target =
          ColourValue(srgb: (r: 0.5, g: 0.45, b: 0.4), xyz: (x: 0.2, y: 0.19, z: 0.14), oklch: (l: 0.5, c: 0.03, h: 60));

      final recipes = engine.inverse(target, mixedPalette, const MixOptions());

      // THEN no recipe spans media, and each recipe's declared medium matches
      // its paints' medium (the group it was searched in).
      expect(recipes, isNotEmpty);
      for (final r in recipes) {
        final media = r.parts.keys.map((id) => idToMedium[id]).toSet();
        expect(media, hasLength(1), reason: '${r.parts.keys} spans $media');
        expect(media.single, r.medium);
      }
    });

    test('the non-first medium is searched, and its paint can win', () {
      // GIVEN a mixed palette whose target is a pure OIL paint's colour (oil is
      // second), so only searching the oil group can reach it. Rejects a solver
      // that searches only `palette.first.medium` (acrylic).
      const oilYellowId = 'oil.yellow_ochre';
      final target = engine.forward(const {oilYellowId: 1.0});

      final recipes = engine.inverse(target, mixedPalette, const MixOptions());

      // THEN every recipe is single-medium, and the best is the oil paint that
      // sits on the target — the oil group was genuinely searched.
      expect(recipes, isNotEmpty);
      for (final r in recipes) {
        expect(r.parts.keys.map((id) => idToMedium[id]).toSet(), hasLength(1));
      }
      expect(recipes.first.medium, Medium.oil);
      expect(recipes.first.deltaE00, lessThan(1.0));
    });
  });

  group('CustomKmEngine.inverse — per-subset refinement (SOLVER-6)', () {
    const engine = CustomKmEngine();
    final palette = PigmentTable.load(Medium.acrylic).pigments;

    test('a near-pure reachable tint is matched far tighter than the coarse '
        'grid (refinement)', () {
      // GIVEN a target that is EXACTLY a palette mixture at an off-grid ratio —
      // white 0.975 + blue 0.025 — reachable by definition but sitting between
      // the 1/12 coarse grid node and pure white. A solver that searched only
      // the coarse grid would land ≈ 6.4 ΔE00 away (over the ≤ 5 ceiling).
      final target = engine.forward(const {
        'acrylic.titanium_white': 0.975,
        'acrylic.phthalo_blue': 0.025,
      });

      final best = engine.inverse(target, palette, const MixOptions()).first;

      // THEN successive refinement brings it well under 1 ΔE00 — this would fail
      // against the coarse-grid-only optimizer, pinning the tightening.
      expect(best.deltaE00, lessThan(1.0),
          reason: 'refinement must match a reachable near-pure tint tightly');
      expect(best.outOfGamut, isFalse);
      expect(best.parts.values, everyElement(greaterThan(0.0)),
          reason: 'every share stays strictly positive');
      expect(best.parts.values.fold<double>(0, (a, b) => a + b),
          closeTo(1.0, 1e-9));
    });

    test('an extreme near-white tint converges at the simplex boundary', () {
      // GIVEN an exact mixture whose optimal blue share (0.001) is smaller than
      // the finest refinement step, so the hill-climb drives one share toward 0
      // and the other toward 1 and must reject moves that would cross either
      // bound — exercising the strictly-positive guard on both sides.
      final target = engine.forward(const {
        'acrylic.titanium_white': 0.999,
        'acrylic.phthalo_blue': 0.001,
      });

      final best = engine.inverse(target, palette, const MixOptions()).first;

      // THEN the fit still lands within the accuracy ceiling with valid shares.
      expect(best.deltaE00, lessThanOrEqualTo(5.0));
      expect(best.parts.values, everyElement(greaterThan(0.0)));
      expect(best.parts.values, everyElement(lessThan(1.0)));
    });

    test('a three-paint off-grid target is refined (2-D simplex moves)', () {
      // GIVEN a reachable three-paint mixture at off-grid shares, so refinement
      // runs over a 2-D simplex (shifting volume between each pair of paints).
      final target = engine.forward(const {
        'acrylic.titanium_white': 0.62,
        'acrylic.phthalo_blue': 0.23,
        'acrylic.naphthol_red': 0.15,
      });

      final recipes = engine.inverse(target, palette, const MixOptions());
      final threePaint =
          recipes.firstWhere((r) => r.parts.length == 3, orElse: () => recipes.first);

      // THEN the best three-paint recipe is matched tightly (the coarse 1/12
      // grid cannot land on these shares).
      expect(threePaint.parts, hasLength(3));
      expect(threePaint.deltaE00, lessThan(1.0),
          reason: 'refinement reaches a reachable 3-paint mix closely');
    });
  });

  group('CustomKmEngine.inverse — performance guard + precompute (SOLVER-7)', () {
    const engine = CustomKmEngine();
    final acrylic = PigmentTable.load(Medium.acrylic).pigments;

    // A ~15-paint single-medium palette (the AC-20 search size), built by
    // cloning the acrylic paints under distinct ids so the subset search is
    // genuinely combinatorial.
    List<Pigment> fifteen() => <Pigment>[
          for (var i = 0; i < 15; i++)
            Pigment(
              id: 'perf.paint_$i',
              name: acrylic[i % acrylic.length].name,
              pigmentIndex: acrylic[i % acrylic.length].pigmentIndex,
              medium: acrylic[i % acrylic.length].medium,
              k: acrylic[i % acrylic.length].k,
              s: acrylic[i % acrylic.length].s,
              opacity: acrylic[i % acrylic.length].opacity,
              provenance: acrylic[i % acrylic.length].provenance,
              sourceRef: acrylic[i % acrylic.length].sourceRef,
            ),
        ];

    test('a high maxPaints over a large palette is capped to the budgeted '
        'search (same result as the default cap)', () {
      // GIVEN a 15-paint palette and a target. WHEN the caller requests a large
      // maxPaints (8) the cumulative subset count (22 818) far exceeds the
      // budget, so the guard lowers the effective per-recipe cap — exercising
      // the break arm of the budget loop. THEN the solve still returns the
      // top-3, and returns the SAME recipes as the default maxPaints=4 solve:
      // the extra large subsets the uncapped search would enumerate never beat
      // the budgeted ones, so the cap bounds the work without changing results.
      final palette = fifteen();
      final target = engine.forward(const {
        'acrylic.titanium_white': 0.6,
        'acrylic.phthalo_blue': 0.25,
        'acrylic.naphthol_red': 0.15,
      });
      final capped = engine.inverse(target, palette, const MixOptions(topK: 3));
      final greedy = engine.inverse(
          target, palette, const MixOptions(topK: 3, maxPaints: 8));

      expect(greedy, isNotEmpty);
      expect(greedy.length, lessThanOrEqualTo(3));
      expect(greedy.length, capped.length);
      for (var i = 0; i < greedy.length; i++) {
        expect(greedy[i].parts, capped[i].parts,
            reason: 'the guard must not change the ranked recipes, only bound '
                'the search');
        expect(greedy[i].deltaE00, capped[i].deltaE00);
      }
      // Every returned recipe stays within the budgeted per-recipe size.
      expect(greedy.map((r) => r.parts.length), everyElement(lessThanOrEqualTo(4)));
    });

    test('a small palette still honours the caller full maxPaints (cap does '
        'not bite)', () {
      // GIVEN the small acrylic palette (3 paints): the cumulative subset count
      // at maxPaints=4 (7 subsets) is far under budget, so the budget loop runs
      // all the way to `limit` without breaking — the non-break path. THEN a
      // recipe using every palette paint (3) is reachable, so the cap did not
      // lower the effective maximum below the palette size.
      final target = engine.forward(const {
        'acrylic.titanium_white': 0.4,
        'acrylic.phthalo_blue': 0.35,
        'acrylic.naphthol_red': 0.25,
      });
      final recipes = engine.inverse(target, acrylic, const MixOptions());
      expect(recipes.any((r) => r.parts.length == acrylic.length), isTrue,
          reason: 'a 3-paint palette at maxPaints=4 must still search the '
              'full-palette subset');
    });

    test('BoundForward reproduces forwardColour bit-for-bit (precompute)', () {
      // The precompute helper must be a pure optimization: a bound evaluation
      // and the equivalent forwardColour call return identical colours, so the
      // ranking/accuracy ACs are untouched. Checked across every subset size.
      final rng = math.Random(7);
      for (var size = 1; size <= acrylic.length; size++) {
        final subset = acrylic.sublist(0, size);
        final bound = BoundForward(subset);
        Pigment resolve(String id) => subset.firstWhere((p) => p.id == id);
        for (var t = 0; t < 8; t++) {
          final shares = <double>[
            for (var i = 0; i < size; i++) rng.nextDouble() + 0.01,
          ];
          final got = bound.colourFor(shares);
          final parts = <String, double>{
            for (var i = 0; i < size; i++) subset[i].id: shares[i],
          };
          final ref = forwardColour(parts, resolve);
          expect(got.xyz.x, ref.xyz.x);
          expect(got.xyz.y, ref.xyz.y);
          expect(got.xyz.z, ref.xyz.z);
        }
      }
    });

    test('BoundForward rejects an empty paint set', () {
      expect(() => BoundForward(const <Pigment>[]), throwsArgumentError);
    });

    test('BoundForward rejects paints spanning media', () {
      final mixed = <Pigment>[
        PigmentTable.load(Medium.acrylic).pigments.first,
        PigmentTable.load(Medium.oil).pigments.first,
      ];
      expect(() => BoundForward(mixed), throwsArgumentError);
    });
  });

  group('CustomKmEngine.inverse — wet/dry state toggle (TUNE-4)', () {
    const engine = CustomKmEngine();
    final palette = PigmentTable.load(Medium.acrylic).pigments;
    final target = engine.forward(const {
      'acrylic.titanium_white': 0.6,
      'acrylic.phthalo_blue': 0.4,
    });

    test('the dry solve keeps the wet recipe but re-renders it darker', () {
      // The toggle rides on MixOptions.wet, read through inverse (gate G-2 —
      // forward()/the solve stay option-free). The dry state is a post-prediction
      // re-render: same recipes, same ΔE00, only the colour moves.
      final wet = engine.inverse(target, palette, const MixOptions(wet: true));
      final dry = engine.inverse(target, palette, const MixOptions(wet: false));
      expect(wet, isNotEmpty);
      expect(dry, hasLength(wet.length));

      final offset = configForMedium(Medium.acrylic).wetDry;
      expect(offset, isNot(WetDryTransform.none),
          reason: 'acrylic documents a non-identity drying offset');

      for (var i = 0; i < wet.length; i++) {
        expect(dry[i].parts, wet[i].parts,
            reason: 'wet→dry never re-solves, so the parts are unchanged');
        expect(dry[i].deltaE00, wet[i].deltaE00);
        expect(dry[i].provenance, wet[i].provenance);
        expect(dry[i].outOfGamut, wet[i].outOfGamut);
        expect(dry[i].verdict, wet[i].verdict);
        // Only the predicted colour moves — and acrylic dries darker.
        expect(dry[i].colour, isNot(wet[i].colour));
        expect(dry[i].colour.xyz.y, lessThan(wet[i].colour.xyz.y),
            reason: "acrylic's dry colour is darker (lower Y)");
      }
    });

    test('wet is the default state (the if-wet return arm)', () {
      final byDefault = engine.inverse(target, palette, const MixOptions());
      final explicitWet =
          engine.inverse(target, palette, const MixOptions(wet: true));
      expect(byDefault.first.colour, explicitWet.first.colour,
          reason: 'MixOptions defaults to the wet state, so colours are '
              'identical to an explicit wet solve');
    });
  });

  group('deltaE2000 colour difference (solver metric)', () {
    test('identical colours are ΔE00 0; XYZ wrapper agrees with Lab', () {
      expect(deltaE2000Lab(50, 10, -20, 50, 10, -20), closeTo(0, 1e-12));
      // The XYZ wrapper exercises the CIELAB f() in both regimes: a large
      // channel (cube-root arm) and a near-zero channel (linear arm).
      const bright = (x: 0.9, y: 0.95, z: 1.0);
      const dark = (x: 0.001, y: 0.0012, z: 0.0015);
      expect(deltaE2000Xyz(bright, bright), closeTo(0, 1e-12));
      expect(deltaE2000Xyz(bright, dark), greaterThan(10.0));
    });

    test('neutral greys: the chroma-zero and (0,0) hue branches', () {
      // Both achromatic → c1p*c2p == 0 in both dhp and hBarp, and hp(0,0)==0.
      expect(deltaE2000Lab(40, 0, 0, 60, 0, 0), greaterThan(0));
      // One achromatic, one chromatic → still c1p*c2p == 0.
      expect(deltaE2000Lab(50, 0, 0, 50, 30, 10), greaterThan(0));
    });

    test('hue arithmetic branches across the 0°/360° seam', () {
      // A modest hue gap (≤180°) → the plain dhp/hBarp arms, b>0 → hp positive.
      expect(_deltaAtHues(30, 60), greaterThan(0));
      // Gap > 180° with hue sum < 360° → dhp ">180" arm, hBarp "+360" arm; the
      // 200° colour has b<0, exercising hp's negative→+360 branch.
      expect(_deltaAtHues(10, 200), greaterThan(0));
      // Gap < −180° (first hue the larger) with hue sum ≥ 360° → dhp "+360" arm
      // and hBarp "−360" arm; the 350° colour has b<0 (hp negative branch).
      expect(_deltaAtHues(350, 150), greaterThan(0));
    });
  });

  group('CustomKmEngine.forward resolution and guards', () {
    const engine = CustomKmEngine();

    test('resolves an oil-medium paint id (second medium table searched)', () {
      // Covers the resolver loop continuing past the acrylic table to oil.
      final oil = engine.forward(const {'oil.lead_white': 1.0});
      expect(oil, isA<ColourValue>());
    });

    test('an unknown paint id throws ArgumentError', () {
      expect(
        () => engine.forward(const {'acrylic.not_a_paint': 1.0}),
        throwsArgumentError,
      );
    });

    test('resolves a curated-default-palette id not in the synthetic tables '
        '(TUNE-3 fallback)', () {
      // The curated default palette's real paints are not in the synthetic
      // solver tables, so the resolver must fall back to defaultPaletteById.
      // Covers the curated-found arm of _resolve; rejects a resolver that only
      // searches the medium tables and throws on a shipped default-palette id.
      final id = curatedAcrylicPaletteIds.first;
      expect(defaultPaletteById(id), isNotNull);
      expect(engine.forward({id: 1.0}), isA<ColourValue>());
    });

    test('a mixture spanning two media throws ArgumentError', () {
      expect(
        () => engine.forward(const {
          'acrylic.titanium_white': 0.5,
          'oil.lead_white': 0.5,
        }),
        throwsArgumentError,
      );
    });

    test('an empty mixture throws ArgumentError', () {
      expect(() => engine.forward(const {}), throwsArgumentError);
    });

    test('parts summing to zero throw ArgumentError', () {
      expect(
        () => engine.forward(const {'acrylic.titanium_white': 0.0}),
        throwsArgumentError,
      );
    });
  });

  group('SpectralBaselineEngine — single-constant baseline (PROD-3, AC-25)', () {
    const engine = SpectralBaselineEngine();
    const whiteId = 'acrylic.titanium_white';
    const blueId = 'acrylic.phthalo_blue';
    const redId = 'acrylic.naphthol_red';
    final acrylic = PigmentTable.load(Medium.acrylic).pigments;
    final oil = PigmentTable.load(Medium.oil).pigments;

    test('implements MixingEngine; forward is spectrumToColour(reflectanceOf); '
        'an empty palette has no recipes', () {
      expect(engine, isA<MixingEngine>());
      final reflectance = engine.reflectanceOf(const {whiteId: 1.0});
      expect(reflectance, hasLength(CanonicalGrid.bins));
      // forward shares the one pipeline: it is exactly the colour of the
      // predicted reflectance.
      expect(engine.forward(const {whiteId: 1.0}),
          spectrumToColour(engine.reflectanceOf(const {whiteId: 1.0})));
      // The empty-palette guard returns no recipes (not an error).
      expect(engine.inverse(_target, const [], const MixOptions()), isEmpty);
    });

    test('is genuinely single-constant: a pure paint matches the two-constant '
        'engine, but a differently-scattering MIX diverges', () {
      const measured = CustomKmEngine();
      // A single paint has one component, so (K/S)mix == Kmix/Smix either way —
      // the two models agree exactly on a pure paint (a control that rejects a
      // baseline that is secretly a no-op / constant output).
      expect(engine.reflectanceOf(const {whiteId: 1.0}),
          measured.reflectanceOf(const {whiteId: 1.0}));
      // A mix of paints whose scattering differs (opaque white vs a chromatic
      // paint) is where mixing K/S ratios (single-constant) and mixing K and S
      // separately (two-constant) part ways. Rejects a baseline that just copies
      // the two-constant engine.
      const mix = {whiteId: 0.6, blueId: 0.4};
      final base = engine.reflectanceOf(mix);
      final two = measured.reflectanceOf(mix);
      expect(spectraEqual(base, two), isFalse,
          reason: 'the single-constant mix must differ from the two-constant '
              'mix when scattering differs across paints');
    });

    test('inverse returns palette-only recipes, parts summing to 1, ranked '
        'best-first, capped at topK', () {
      final target = engine.forward(const {whiteId: 0.7, blueId: 0.3});
      const opts = MixOptions(topK: 4);
      final recipes = engine.inverse(target, acrylic, opts);
      expect(recipes, isNotEmpty);
      expect(recipes.length, lessThanOrEqualTo(opts.topK));
      final paletteIds = acrylic.map((p) => p.id).toSet();
      for (final r in recipes) {
        expect(r.parts, isNotEmpty);
        expect(r.parts.keys, everyElement(isIn(paletteIds)));
        expect(r.parts.values, everyElement(greaterThan(0.0)));
        expect(r.parts.values.fold<double>(0, (a, b) => a + b),
            closeTo(1.0, 1e-9));
        expect(r.medium, Medium.acrylic);
        expect(r.outOfGamut, isFalse);
        expect(r.verdict, contains('ΔE00'));
        expect(r.provenance, Provenance.estimated); // synthetic palette
      }
      for (var i = 1; i < recipes.length; i++) {
        expect(recipes[i].deltaE00,
            greaterThanOrEqualTo(recipes[i - 1].deltaE00));
      }
      // A target the baseline itself can mix is matched closely (refinement).
      expect(recipes.first.deltaE00, lessThan(1.0));
    });

    test('maxPaints caps the subset size (the <= topK, no-truncation arm)', () {
      final target = engine.forward(const {whiteId: 0.7, blueId: 0.3});
      // maxPaints 1 → one single-paint recipe per palette paint (3 ≤ default
      // topK 5, so the ranked list is returned whole, not sublisted).
      final recipes =
          engine.inverse(target, acrylic, const MixOptions(maxPaints: 1));
      expect(recipes, hasLength(acrylic.length));
      expect(recipes, everyElement(predicate<Recipe>((r) => r.parts.length == 1)));
    });

    test('a mixed-media palette never produces a recipe spanning media, and the '
        'non-first medium is genuinely searched', () {
      final mixedPalette = <Pigment>[...acrylic, ...oil];
      final idToMedium = <String, Medium>{
        for (final p in mixedPalette) p.id: p.medium,
      };
      // Target a pure OIL paint's colour (oil is the second group): only
      // searching the oil group can reach it. Rejects a solver that searches
      // only the first medium.
      final target = engine.forward(const {'oil.yellow_ochre': 1.0});
      final recipes = engine.inverse(target, mixedPalette, const MixOptions());
      expect(recipes, isNotEmpty);
      for (final r in recipes) {
        final media = r.parts.keys.map((id) => idToMedium[id]).toSet();
        expect(media, hasLength(1), reason: '${r.parts.keys} spans $media');
        expect(media.single, r.medium);
      }
      expect(recipes.first.medium, Medium.oil);
      expect(recipes.first.deltaE00, lessThan(1.0));
    });

    test('an unreachable target: every recipe is flagged out-of-gamut and never '
        'claimed a match', () {
      // The acrylic palette (white, blue, red) has no green primary, so a vivid
      // pure green is unreachable by any single-constant mixture of it.
      const green = ColourValue(
        srgb: (r: 0.0, g: 1.0, b: 0.0),
        xyz: (x: 0.3576, y: 0.7152, z: 0.1192),
        oklch: (l: 0.866, c: 0.295, h: 142.5),
      );
      final recipes = engine.inverse(green, acrylic, const MixOptions());
      expect(recipes, isNotEmpty);
      const ceiling = 5.0;
      for (final r in recipes) {
        expect(r.outOfGamut, isTrue);
        expect(r.deltaE00, greaterThan(ceiling));
        expect(r.verdict, contains('out of gamut'));
        expect(r.verdict, contains(r.deltaE00.toStringAsFixed(2)));
      }
    });

    group('ranking tie-break (prefer fewer paints on an exact ΔE00 tie)', () {
      // Six identical-reflectance paints (same K, same S, distinct ids): every
      // single-constant mixture predicts the same colour at any ratio, so all
      // subsets tie EXACTLY on ΔE00 — exercising the byDelta == 0 branch and
      // proving the fewer-paint secondary key, not sort order, decides the rank.
      final k = Float32List.fromList(
          [for (var i = 0; i < CanonicalGrid.bins; i++) 0.07 + 0.015 * i]);
      final s =
          Float32List.fromList(List<double>.filled(CanonicalGrid.bins, 0.4));
      Pigment twin(String id) => Pigment(
            id: id,
            name: id,
            pigmentIndex: 'PX',
            medium: Medium.acrylic,
            k: k,
            s: s,
            opacity: 0.5,
            provenance: Provenance.estimated,
            sourceRef: 'synthetic:$id',
          );
      final twins = [for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) twin(id)];
      const target = ColourValue(
        srgb: (r: 0.5, g: 0.5, b: 0.5),
        xyz: (x: 0.2, y: 0.2, z: 0.2),
        oklch: (l: 0.5, c: 0.0, h: 0.0),
      );

      test('on an exact ΔE00 tie the fewer-paint recipe ranks first', () {
        final recipes =
            engine.inverse(target, twins, const MixOptions(topK: 100));
        expect(recipes, hasLength(56)); // C(6, 1..4)
        final tied = recipes.first.deltaE00;
        expect(recipes,
            everyElement(predicate<Recipe>((r) => r.deltaE00 == tied)));
        final counts = [for (final r in recipes) r.parts.length];
        expect(counts.first, 1);
        expect(counts.last, 4);
        for (var i = 1; i < counts.length; i++) {
          expect(counts[i], greaterThanOrEqualTo(counts[i - 1]));
        }
      });

      test('truncation to topK keeps the tie-break winners (the sublist arm)', () {
        final recipes = engine.inverse(target, twins, const MixOptions(topK: 6));
        expect(recipes, hasLength(6));
        expect(recipes,
            everyElement(predicate<Recipe>((r) => r.parts.length == 1)),
            reason: 'the simplest recipes outrank equal-ΔE00 heavier ones');
      });
    });

    test('refinement drives a near-pure reachable tint tight, respecting the '
        'strictly-positive simplex bounds', () {
      // An exact baseline mixture at an off-grid, near-boundary ratio: the
      // optimal blue share (0.001) is below the finest refinement step, so the
      // hill-climb drives one share toward 0 and the other toward 1 and must
      // reject moves crossing either bound (the trial[j] <= 0 / trial[i] >= 1
      // guard, both sides).
      final target = engine.forward(const {whiteId: 0.999, blueId: 0.001});
      final best = engine.inverse(target, acrylic, const MixOptions()).first;
      expect(best.deltaE00, lessThanOrEqualTo(5.0));
      expect(best.parts.values, everyElement(greaterThan(0.0)));
      expect(best.parts.values, everyElement(lessThan(1.0)));
    });

    test('a three-paint off-grid target is refined over the 2-D simplex', () {
      final target =
          engine.forward(const {whiteId: 0.62, blueId: 0.23, redId: 0.15});
      final recipes = engine.inverse(target, acrylic, const MixOptions());
      final threePaint = recipes.firstWhere((r) => r.parts.length == 3,
          orElse: () => recipes.first);
      expect(threePaint.parts, hasLength(3));
      expect(threePaint.deltaE00, lessThan(1.0),
          reason: 'refinement reaches a reachable 3-paint mix closely');
    });

    test('forward resolves an oil-medium id (second medium table), and rejects '
        'an unknown id and a cross-medium mix', () {
      // The resolver loop must continue past the acrylic table to oil.
      expect(engine.forward(const {'oil.lead_white': 1.0}), isA<ColourValue>());
      expect(() => engine.forward(const {'acrylic.not_a_paint': 1.0}),
          throwsArgumentError);
      // A single mixture spanning media is rejected by the bound reducer.
      expect(
        () => engine.reflectanceOf(const {whiteId: 0.5, 'oil.lead_white': 0.5}),
        throwsArgumentError,
      );
    });

    test('forward resolves a curated-default-palette id (TUNE-3 fallback), so '
        'the baseline resolves the same pigment universe as the two-constant '
        'engine (AC-25)', () {
      final id = curatedAcrylicPaletteIds.first;
      expect(engine.forward({id: 1.0}), isA<ColourValue>());
    });
  });
}
