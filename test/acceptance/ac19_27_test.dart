import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

import 'harness/harness.dart';

/// Acceptance band 3 (ITEST-4): AC-19 … AC-27 — the SOLVER cross-medium /
/// performance constraints, the TUNE natural-colour levers, the PROD provenance
/// and A/B-interface guarantees, and the two @stretch S6 scenarios.
///
/// One pending integration test per AC, driven entirely through the package's
/// public surface. Each test calls [ac] in its `skip:` argument so it is skipped
/// in the default run and executed under `PIGMENT_KM_RUN_PENDING=true` (the red
/// baseline), where it must fail for the right reason — on a Then, on a When
/// (the behaviour throwing its documented `UnimplementedError`), or on a Given
/// precondition naming the owning gate/phase — until that behaviour phase lands.
///
/// Covered: AC-19 cross-medium (SOLVER-5), AC-20 performance budget (SOLVER-7),
/// AC-21 curated-palette no-neon (TUNE-3), AC-22 chroma-penalty tie-break
/// (TUNE-2), AC-23 wet/dry toggle (TUNE-4), AC-24 provenance tiering (PROD-2),
/// AC-25 A/B interchangeable engines (PROD-3), AC-26 finite-thickness glazing
/// (STRETCH-2, @stretch · G-7) and AC-27 metamerism index (STRETCH-3, @stretch ·
/// G-7).
///
/// AC-26/27 are the optional S6 scenarios: they are tagged `@stretch` so
/// `dart test -x stretch` excludes them, and their finite-thickness-layering and
/// multi-illuminant-metamerism public APIs are deliberately NOT frozen here —
/// their scope is gated behind the still-open G-7. Until G-7 approves the scope
/// and STRETCH-2/3 freeze those APIs, each asserts a precondition naming G-7, and
/// its full Given/When/Then/Rejects is documented in-place for that phase to
/// implement. See the ITEST-4 Checkpoint and the G-2 review notes.
void main() {
  group('SOLVER — cross-medium and performance constraints', () {
    test('AC-19 · TestAC19_CrossMedium: a single recipe never spans media', () {
      final engine = customEngine();
      // GIVEN a palette containing BOTH acrylic and oil paints — so a solver
      // that ignored the medium constraint COULD mix across media.
      final palette = <Pigment>[
        ...PigmentTable.load(Medium.acrylic).pigments,
        ...PigmentTable.load(Medium.oil).pigments,
      ];
      final idToMedium = <String, Medium>{
        for (final p in palette) p.id: p.medium,
      };
      // Given checks: both media are genuinely present in the palette.
      final paletteMedia = palette.map((p) => p.medium).toSet();
      expect(paletteMedia, containsAll(<Medium>{Medium.acrylic, Medium.oil}),
          reason: 'the palette must span both acrylic and oil paints');
      final target = colourFromSrgb((r: 0.55, g: 0.5, b: 0.45));

      // WHEN the solver returns recipes for a target drawn from the mixed palette.
      final recipes = engine.inverse(target, palette, const MixOptions());

      // THEN every returned recipe uses paints of exactly one medium, and that
      // medium matches the recipe's declared medium — the solver searched each
      // medium's paints separately. Rejects a solver that mixes acrylic with oil.
      expect(recipes, isNotEmpty);
      for (final r in recipes) {
        final media = r.parts.keys.map((id) => idToMedium[id]).toSet();
        expect(media, hasLength(1),
            reason: 'recipe ${r.parts.keys.toList()} spans media $media');
        expect(media.single, r.medium,
            reason: "the recipe's declared medium must match its paints' medium");
      }

      // CONTROL (SOLVER-5 augmentation) — prove the solver genuinely searches
      // EACH medium separately, not just the first one in the palette, and still
      // never spans media. The target is the colour of a pure OIL paint; oil is
      // SECOND in the palette, so a solver that searched only the first medium's
      // paints (acrylic — white/blue/red, no yellow) could never reach it, while
      // the correct partitioned solver searches the oil group too and returns
      // that oil paint as the clear best. A cross-medium mixture cannot even be
      // evaluated — the forward model refuses to span media — so the constraint
      // is enforced at enumeration, which choosing an out-of-first-medium target
      // exercises. Rejects a solver that searches only `palette.first.medium`.
      const oilYellowId = 'oil.yellow_ochre';
      final oilTarget = engine.forward(const {oilYellowId: 1.0});
      final oilRecipes =
          engine.inverse(oilTarget, palette, const MixOptions());

      expect(oilRecipes, isNotEmpty);
      for (final r in oilRecipes) {
        final media = r.parts.keys.map((id) => idToMedium[id]).toSet();
        expect(media, hasLength(1),
            reason: 'recipe ${r.parts.keys.toList()} spans media $media');
        expect(media.single, r.medium);
      }
      // The oil group WAS searched: its pure paint is the best recipe and sits
      // on the target (ΔE00 ≈ 0), which no acrylic-only mixture can reach.
      final best = oilRecipes.first;
      expect(best.medium, Medium.oil,
          reason: 'the best recipe for an oil target must come from the oil '
              'group — so the solver searched past the first medium');
      final bestDist = deltaE00(oilTarget.xyz, best.colour.xyz);
      expect(bestDist, lessThan(1.0),
          reason: 'the pure oil paint reaches its own colour');
      // The temptation was real: the acrylic group alone lands strictly farther,
      // so a first-medium-only solver would have returned a visibly worse match.
      final acrylicOnly =
          palette.where((p) => p.medium == Medium.acrylic).toList();
      final acrylicBest =
          engine.inverse(oilTarget, acrylicOnly, const MixOptions());
      expect(deltaE00(oilTarget.xyz, acrylicBest.first.colour.xyz),
          greaterThan(bestDist),
          reason: 'acrylic alone cannot reach an oil target as well as oil can');
    }, skip: ac('AC-19'));

    test('AC-20 · TestAC20_Performance: the solver returns within the '
        'performance budget', () {
      final engine = customEngine();
      // GIVEN a declared palette of about 15 paints. Built by cloning the
      // synthetic paints under distinct ids (caller-supplied input, a single
      // medium so the cross-medium split does not shrink the search) — the
      // search size, not the colours, is what this AC times.
      final palette = _fifteenPaintPalette();
      expect(palette.length, 15,
          reason: 'the performance budget is measured on ~15 paints');
      final target = colourFromSrgb((r: 0.6, g: 0.55, b: 0.5));
      const opts = MixOptions(topK: 3);

      // WHEN the solver is asked for the top three recipes for a target.
      final sw = Stopwatch()..start();
      final recipes = engine.inverse(target, palette, opts);
      sw.stop();

      // THEN it returns (up to) the top three within about 1–2 s — rejects an
      // exponential search that blows the budget on a 15-paint palette.
      expect(recipes, isNotEmpty);
      expect(recipes.length, lessThanOrEqualTo(3));
      expect(sw.elapsed, lessThanOrEqualTo(const Duration(seconds: 2)),
          reason: 'a ~15-paint top-3 solve must return within ~1–2 s (SI NFR)');

      // AUGMENTATION (SOLVER-7): the budget must hold even when the caller asks
      // for more paints per recipe. The subset search is combinatorial in
      // maxPaints, so without SOLVER-7's performance guard a maxPaints=8 solve
      // over ~15 paints enumerates tens of thousands of subsets and runs for
      // many seconds (≈8.7 s measured before the guard; already ≈2.6 s at
      // maxPaints=5). The guard caps the effective per-recipe paint count so the
      // search stays within the budget. This rejects an uncapped exponential
      // search — a reject the in-budget default-maxPaints solve cannot make.
      const greedy = MixOptions(topK: 3, maxPaints: 8);
      final swGreedy = Stopwatch()..start();
      final greedyRecipes = engine.inverse(target, palette, greedy);
      swGreedy.stop();
      expect(greedyRecipes, isNotEmpty);
      expect(greedyRecipes.length, lessThanOrEqualTo(3));
      expect(swGreedy.elapsed, lessThanOrEqualTo(const Duration(seconds: 2)),
          reason: 'the performance guard must keep even a high-maxPaints solve '
              'within the budget (rejects an uncapped exponential search)');
    }, skip: ac('AC-20'));
  });

  group('TUNE — natural, muted colour', () {
    test('AC-21 · TestAC21_NoNeon: the curated default palette cannot produce '
        'neon mixes', () {
      final engine = customEngine();
      // GIVEN the curated naturalistic default palette for a medium. Until
      // TUNE-3 ships the real Zorn-style acrylic palette (G-3), this is the
      // muted synthetic palette; TUNE-3 augments this test to the shipped set.
      final palette = synthPigments();
      expect(palette, isNotEmpty);
      // The naturalistic chroma ceiling for this palette. (TUNE-3 confirms/tunes
      // the exact ceiling for the shipped curated palette; a neon primary such as
      // pure sRGB green, OKLCh C≈0.295, lies well above it.)
      const chromaCeiling = 0.25;

      // WHEN any mixture of that palette is predicted …
      final paints = palette.map((p) => p.id).toList();
      final mixes = <Map<String, double>>[
        for (final id in paints) <String, double>{id: 1.0},
        for (var i = 0; i < paints.length; i++)
          for (var j = i + 1; j < paints.length; j++)
            <String, double>{paints[i]: 0.5, paints[j]: 0.5},
      ];
      // THEN no predicted mixture exceeds the naturalistic chroma ceiling —
      // rejects a palette that admits neon primaries.
      for (final mix in mixes) {
        final predicted = engine.forward(mix);
        expect(predicted.oklch.c, lessThanOrEqualTo(chromaCeiling),
            reason: 'mixture $mix exceeds the naturalistic chroma ceiling');
      }

      // AND a muted earth target is reachable within the recipe accuracy target …
      const opts = MixOptions();
      final muted = colourFromSrgb((r: 0.42, g: 0.34, b: 0.26));
      final mutedRecipes = engine.inverse(muted, palette, opts);
      expect(mutedRecipes, isNotEmpty);
      expect(mutedRecipes.first.deltaE00, lessThanOrEqualTo(opts.gamutThreshold),
          reason: 'a muted earth target must be reachable within ΔE00 ≤ 5');
      expect(mutedRecipes.first.outOfGamut, isFalse);
      // … while a neon target is honestly flagged out-of-gamut, never faked.
      final neonRecipes = engine.inverse(oogColour, palette, opts);
      expect(neonRecipes, isNotEmpty);
      expect(neonRecipes.first.outOfGamut, isTrue,
          reason: 'a neon target must be flagged out-of-gamut by a muted palette');
    }, skip: ac('AC-21'));

    test('AC-22 · TestAC22_ChromaPenalty: the chroma penalty breaks ΔE00 ties '
        'toward the more muted recipe', () {
      final engine = customEngine();
      final palette = synthPigments();
      final target = colourFromSrgb((r: 0.5, g: 0.47, b: 0.5));
      // GIVEN the solver's recipes ranked WITHOUT the chroma penalty — pure ΔE00.
      final plain = engine.inverse(
          target, palette, const MixOptions(chromaPenalty: false));
      final penalised = engine.inverse(
          target, palette, const MixOptions(chromaPenalty: true));
      expect(plain, isNotEmpty);
      expect(penalised, isNotEmpty);

      // Given check: with the penalty OFF the ranking is ΔE00-only — monotonic
      // non-decreasing. Rejects a penalty that leaks into the plain ranking.
      for (var i = 1; i < plain.length; i++) {
        expect(plain[i].deltaE00, greaterThanOrEqualTo(plain[i - 1].deltaE00),
            reason: 'penalty-off ranking must depend on ΔE00 alone');
      }

      // Check every adjacent pair that TIES on ΔE00 in the plain ranking but
      // differs in chroma — the only case the penalty is defined to reorder.
      // This natural-tie sweep is a SOFT bonus: the synthetic palette does not
      // deterministically produce a differing-chroma ΔE00 tie (same as AC-15's
      // base test), so the GUARANTEED tie — and the decisive assertion that the
      // penalty reorders it — lives in the constructed-tie test below (the
      // TUNE-2 augmentation). Where a natural tie does occur, the lower-chroma
      // member must still rank ahead with the penalty on.
      for (var i = 1; i < plain.length; i++) {
        if ((plain[i].deltaE00 - plain[i - 1].deltaE00).abs() < 1e-9) {
          final loC = plain[i].colour.oklch.c < plain[i - 1].colour.oklch.c
              ? plain[i]
              : plain[i - 1];
          final hiC = identical(loC, plain[i]) ? plain[i - 1] : plain[i];
          if ((hiC.colour.oklch.c - loC.colour.oklch.c).abs() < 1e-9) continue;
          // WHEN the solver ranks the SAME pair with the penalty enabled …
          final posLo = _indexOfRecipe(penalised, loC);
          final posHi = _indexOfRecipe(penalised, hiC);
          expect(posLo, isNonNegative);
          expect(posHi, isNonNegative);
          // THEN the lower-chroma recipe of the tie ranks ahead of the higher.
          expect(posLo, lessThan(posHi),
              reason: 'the penalty must rank the lower-chroma tie member first');
        }
      }
    }, skip: ac('AC-22'));

    test('AC-22 · TestAC22_ChromaPenalty (constructed tie): on a guaranteed '
        'equal-ΔE00 tie the penalty ranks the muted recipe ahead of the '
        'fewer-paint vivid one', () {
      // TUNE-2 augmentation (ITEST *Test augmentations* row TestAC22). The base
      // test's natural-tie sweep may find no differing-chroma ΔE00 tie in the
      // synthetic solve; this case GUARANTEES one and makes the decisive
      // assertion — and, critically, DISCRIMINATES the chroma penalty from the
      // AC-15 fewer-paints tie-break: the muted recipe here uses MORE paints, so
      // only a genuine chroma penalty (not "prefer fewer paints") can rank it
      // first.
      final engine = customEngine();

      // GIVEN two groups of identical-reflectance twins in one medium. Mixing
      // identical-reflectance paints yields that group's single colour at any
      // ratio and paint count (the two-constant sum narrows to Float32
      // precision), so every all-VIVID subset predicts one vivid colour and
      // every all-MUTED subset one muted colour — a deterministic pair of
      // colours, each reachable at several paint counts.
      //   VIVID: a strong absorption bump → chromatic, higher OKLCh chroma.
      //   MUTED: a flat absorption → near-neutral, lower OKLCh chroma.
      final vividK = _bump(peakBin: 9, floor: 0.04, height: 1.6);
      final mutedK = _flat(0.6);
      final s = _flat(0.5);
      final vivid = <Pigment>[
        for (final id in ['vivid_a', 'vivid_b']) _twin(id, vividK, s),
      ];
      final muted = <Pigment>[
        for (final id in ['muted_a', 'muted_b', 'muted_c']) _twin(id, mutedK, s),
      ];
      final palette = <Pigment>[...vivid, ...muted];

      // The two achievable colours (any all-group mix predicts them), read back
      // through the solver on each group alone.
      final probe = colourFromSrgb((r: 0.5, g: 0.5, b: 0.5));
      final vividColour =
          engine.inverse(probe, vivid, const MixOptions()).first.colour;
      final mutedColour =
          engine.inverse(probe, muted, const MixOptions()).first.colour;
      // Given check: the vivid group really is more chromatic than the muted one
      // (so the penalty has a muted recipe to prefer), with a clear gap.
      final cVivid = vividColour.oklch.c;
      final cMuted = mutedColour.oklch.c;
      expect(cVivid - cMuted, greaterThan(0.02),
          reason: 'the vivid group must be measurably more chromatic');

      // Build a target that is EQUIDISTANT (ΔE00) from the two colours, so a
      // 2-paint vivid recipe and a 3-paint muted recipe tie on the raw match
      // cost. The solver measures ΔE00 with the library's `deltaE2000Xyz`, so
      // the search equalises exactly that metric; each group's recipes predict
      // its colour bit-for-bit, so their recipe ΔE00 equal these distances. The
      // target is nudged to the vivid side of the crossover, so the vivid recipe
      // is (infinitesimally) the raw-closer one — the fewer-paint, higher-chroma
      // "default winner" the penalty must overturn.
      var lo = 0.0; // T = vividColour: dVivid < dMuted
      var hi = 1.0; // T = mutedColour: dVivid > dMuted
      late ColourValue target;
      late double dVivid;
      late double dMuted;
      for (var iter = 0; iter < 100; iter++) {
        final t = (lo + hi) / 2;
        final srgb = (
          r: vividColour.srgb.r + (mutedColour.srgb.r - vividColour.srgb.r) * t,
          g: vividColour.srgb.g + (mutedColour.srgb.g - vividColour.srgb.g) * t,
          b: vividColour.srgb.b + (mutedColour.srgb.b - vividColour.srgb.b) * t,
        );
        final candidate = colourFromSrgb(srgb);
        final dv = deltaE2000Xyz(vividColour.xyz, candidate.xyz);
        final dm = deltaE2000Xyz(mutedColour.xyz, candidate.xyz);
        if (dv < dm) {
          lo = t;
          target = candidate;
          dVivid = dv;
          dMuted = dm;
        } else {
          hi = t;
        }
      }
      // Given check: the two distances form a genuine ΔE00 tie (within the
      // 1e-9 the ranking treats as equal) with the vivid side strictly closer,
      // so the raw ranking puts the vivid recipe first — the penalty, not a
      // coincidence of distances, is what can move the muted recipe ahead.
      expect(dMuted - dVivid, greaterThan(0.0),
          reason: 'the vivid colour must be the raw-closer one');
      expect(dMuted - dVivid, lessThan(1e-9),
          reason: 'the two distances must tie within the ranking tolerance');

      final vividIds = {'vivid_a', 'vivid_b'};
      final mutedIds = {'muted_a', 'muted_b', 'muted_c'};

      // WHEN the full palette is solved with the penalty OFF, then ON (topK big
      // enough to return every subset, so both recipes are always present).
      final plain = engine.inverse(
          target, palette, const MixOptions(topK: 100, chromaPenalty: false));
      final penalised = engine.inverse(
          target, palette, const MixOptions(topK: 100, chromaPenalty: true));

      final vividPlain = _indexOfRecipeByIds(plain, vividIds);
      final mutedPlain = _indexOfRecipeByIds(plain, mutedIds);
      final vividPen = _indexOfRecipeByIds(penalised, vividIds);
      final mutedPen = _indexOfRecipeByIds(penalised, mutedIds);
      expect(vividPlain, isNonNegative,
          reason: 'the 2-paint vivid recipe must be returned');
      expect(mutedPlain, isNonNegative,
          reason: 'the 3-paint muted recipe must be returned');
      expect(vividPen, isNonNegative);
      expect(mutedPen, isNonNegative);

      // Given check: the recipes carry the tie and the chroma gap, and the muted
      // recipe genuinely uses MORE paints (3 vs 2) — so ranking it first cannot
      // be the fewer-paints rule doing the work.
      expect((plain[vividPlain].deltaE00 - plain[mutedPlain].deltaE00).abs(),
          lessThan(1e-9),
          reason: 'the two recipes must tie on ΔE00');
      expect(plain[vividPlain].colour.oklch.c,
          greaterThan(plain[mutedPlain].colour.oklch.c),
          reason: 'the vivid recipe must be the higher-chroma one');
      expect(plain[vividPlain].parts.length, 2);
      expect(plain[mutedPlain].parts.length, 3);

      // THEN with the penalty OFF the raw-closer, fewer-paint VIVID recipe
      // outranks the muted one (ΔE00-first ranking) …
      expect(vividPlain, lessThan(mutedPlain),
          reason: 'penalty-off must rank the raw-closer vivid recipe first');
      // … and with the penalty ON the muted recipe is promoted ahead of the
      // vivid one. This REJECTS a no-effect penalty (the vivid recipe would stay
      // ahead) AND the fewer-paints rule masquerading as a chroma penalty (fewer
      // paints would keep the 2-paint vivid recipe first; only a real chroma
      // penalty lifts the 3-paint muted recipe over it).
      expect(mutedPen, lessThan(vividPen),
          reason: 'the chroma penalty must rank the muted recipe ahead of the '
              'fewer-paint vivid one on the tie');
    }, skip: ac('AC-22'));

    test('AC-23 · TestAC23_WetDry: the wet/dry toggle shifts the prediction by '
        "the medium's documented offset", () {
      final engine = customEngine();
      final palette = synthPigments();
      // GIVEN a target solved in the acrylic medium, to be read in its wet and
      // dry states. (The toggle rides on MixOptions.wet; forward() takes no
      // options, so the wet/dry prediction is observed through inverse+Recipe —
      // an interface note flagged for G-2 / behaviour planning.)
      final target = colourFromSrgb((r: 0.45, g: 0.4, b: 0.55));

      // WHEN the same target+palette is solved wet, then dry.
      final wet = engine.inverse(target, palette, const MixOptions(wet: true));
      final dry = engine.inverse(target, palette, const MixOptions(wet: false));
      expect(wet, isNotEmpty);
      expect(dry, isNotEmpty);
      final wetBest = wet.first;
      final dryBest = dry.first;

      // THEN the parts are unchanged — the toggle is a state transform, not a
      // re-solve (rejects an engine that re-solves and changes the recipe).
      expect(dryBest.parts, _partsCloseTo(wetBest.parts),
          reason: 'wet→dry must not change the recipe parts');

      // AND the dry colour differs from the wet colour by the medium's documented
      // drying offset — rejects a no-op wet/dry.
      final wetDry = configForMedium(Medium.acrylic).wetDry;
      expect(wetDry, isNot(WetDryTransform.none),
          reason: 'acrylic must document a non-identity drying offset');
      expect(deltaE00(dryBest.colour.xyz, wetBest.colour.xyz), greaterThan(0.5),
          reason: 'the dry colour must differ measurably from the wet colour');

      // AND acrylic's dry colour is darker (lower luminance) and hue-shifted
      // relative to its wet colour, matching the documented offset's direction.
      if (wetDry.lightnessDelta != 0) {
        expect(dryBest.colour.xyz.y, lessThan(wetBest.colour.xyz.y),
            reason: "acrylic's dry colour must be darker than its wet colour");
      }
      if (wetDry.hueDeltaDeg != 0) {
        expect(
            hueDiffDeg(dryBest.colour.oklch.h, wetBest.colour.oklch.h),
            greaterThan(0.5),
            reason: "acrylic's dry colour must be hue-shifted from its wet one");
      }
    }, skip: ac('AC-23'));
  });

  group('PROD — provenance and the A/B interface', () {
    test('AC-24 · TestAC24_Provenance: recipes from measured data are labelled '
        'Calculated, and user tubes Measured', () {
      final engine = customEngine();
      final base = synthPigments();

      // GIVEN a palette derived from the shipped MEASURED pigment data — every
      // paint tagged Calculated (derived from measured K,S through the model).
      final calculatedPalette = <Pigment>[
        for (final p in base) _retag(p, Provenance.calculated),
      ];
      final target = colourFromSrgb((r: 0.5, g: 0.46, b: 0.5));

      // WHEN a recipe is solved from that measured-data palette and its
      // provenance is read.
      final calcRecipes = engine.inverse(target, calculatedPalette,
          const MixOptions());
      expect(calcRecipes, isNotEmpty);
      // THEN it is Calculated — not Measured and not Estimated. Rejects a model
      // that claims Measured from the dataset, or Estimated from measured data.
      expect(calcRecipes.first.provenance, Provenance.calculated,
          reason: 'a recipe from shipped measured data must be Calculated');

      // GIVEN a palette whose only paint is the user's OWN measured tube
      // (provenance Measured), so any recipe must use it.
      final tube = _retag(base.first, Provenance.measured);
      final tubeRecipes =
          engine.inverse(target, <Pigment>[tube], const MixOptions());
      expect(tubeRecipes, isNotEmpty);
      expect(tubeRecipes.first.parts.keys, contains(tube.id),
          reason: 'the single-tube solve must use the user-measured tube');
      // THEN the recipe using a user-measured tube is Measured.
      expect(tubeRecipes.first.provenance, Provenance.measured,
          reason: "a recipe from the user's measured tube must be Measured");
    }, skip: ac('AC-24'));

    test('AC-25 · TestAC25_ABEngines: the measured-pigment engine and a baseline '
        'engine are interchangeable', () {
      // GIVEN both engines behind the one MixingEngine interface (the harness
      // builders return the `MixingEngine` type; the checks below prove it).
      final measured = customEngine();
      final baseline = baselineEngine();
      expect(measured, isA<MixingEngine>());
      expect(baseline, isA<MixingEngine>());
      final palette = synthPigments();
      final swatches = <ColourValue>[
        colourFromSrgb((r: 0.5, g: 0.45, b: 0.5)),
        colourFromSrgb((r: 0.42, g: 0.34, b: 0.26)),
        colourFromSrgb((r: 0.72, g: 0.76, b: 0.86)),
      ];

      // WHEN both are driven through the identical interface — the same
      // `inverse(target, palette, opts)` call, no caller change between them.
      List<double> abDeltaE00(MixingEngine engine) => <double>[
            for (final s in swatches)
              engine.inverse(s, palette, const MixOptions()).first.deltaE00,
          ];
      final measuredE = abDeltaE00(measured);
      final baselineE = abDeltaE00(baseline);

      // THEN both return recipes through the identical interface with no caller
      // change, and the A/B harness reports each engine's ΔE00 on the same swatch
      // set. Rejects a baseline wired differently (it would not satisfy the
      // interface the same call drives).
      expect(measuredE, hasLength(swatches.length));
      expect(baselineE, hasLength(swatches.length));
      for (final d in <double>[...measuredE, ...baselineE]) {
        expect(d, isNonNegative);
        expect(d.isFinite, isTrue,
            reason: 'each engine must report a finite ΔE00 per swatch');
      }
    }, skip: ac('AC-25'));
  });

  group('STRETCH — optional S6 (gated behind G-7)', () {
    test('AC-26 · TestAC26_Glazing: a glaze over a ground predicts via the '
        'finite-thickness layering equation', () {
      // Un-pended by STRETCH-2 (G-7 ✅ Build STRETCH). Driven through the frozen
      // layering API `glazedReflectance` (design §3.4), public surface only.
      final paints = synthPigments();
      // GIVEN a mixture (a tinted blue glaze) applied as a film of finite
      // thickness X over a ground of known reflectance Rg.
      final glaze = mixTwoConstant(<MixComponent>[
        (k: paints[1].k, s: paints[1].s, weight: 0.7), // phthalo blue
        (k: paints[0].k, s: paints[0].s, weight: 0.3), // opaque white
      ]);
      // The opaque body reflectance of the same mixture (the X → ∞ target).
      final koverS = Float32List(CanonicalGrid.bins);
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        koverS[i] = glaze.k[i] / glaze.s[i];
      }
      final opaque = kmReflectance(koverS);
      // A known, valid ground reflectance distinct from the opaque mix, so the
      // ground genuinely shows through a finite film.
      final ground = Float32List.fromList(
          List<double>.filled(CanonicalGrid.bins, 0.6));
      const xFinite = 1.0;

      // Given checks: X is a finite positive thickness; Rg is a valid spectrum
      // with physical reflectances in (0, 1].
      expect(xFinite.isFinite && xFinite > 0, isTrue);
      expect(ground.length, CanonicalGrid.bins);
      for (final v in ground) {
        expect(v, greaterThan(0));
        expect(v, lessThanOrEqualTo(1));
      }

      // WHEN its layered reflectance is computed.
      final layered =
          glazedReflectance(glaze: glaze, thickness: xFinite, ground: ground);

      // THEN the result is a physical reflectance spectrum on the grid.
      expect(layered.length, CanonicalGrid.bins);
      for (final v in layered) {
        expect(v, inInclusiveRange(0.0, 1.0));
      }

      // CONTROL — as X → ∞ the layered reflectance approaches the opaque form.
      final thick =
          glazedReflectance(glaze: glaze, thickness: 1e6, ground: ground);
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        expect(thick[i], closeTo(opaque[i], 1e-5),
            reason: 'a thick glaze must approach the opaque-form reflectance');
      }

      // And as X → 0 the bare ground shows through — the ground, not the mix,
      // governs a vanishingly thin film.
      final thin =
          glazedReflectance(glaze: glaze, thickness: 1e-6, ground: ground);
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        expect(thin[i], closeTo(ground[i], 1e-3),
            reason: 'a vanishing glaze must reveal the ground');
      }

      // The finite film lies between the ground and the opaque form at every
      // wavelength, and differs from the opaque form — REJECTS reusing the
      // opaque body reflectance (which would ignore the thickness and ground).
      var sawDepartureFromOpaque = false;
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        final lo = math.min(ground[i], opaque[i]);
        final hi = math.max(ground[i], opaque[i]);
        expect(layered[i], inInclusiveRange(lo - 1e-6, hi + 1e-6),
            reason: 'bin $i must lie between the ground and the opaque form');
        if ((layered[i] - opaque[i]).abs() > 1e-3) sawDepartureFromOpaque = true;
      }
      expect(sawDepartureFromOpaque, isTrue,
          reason: 'a finite glaze over a different ground must not equal the '
              'opaque form');

      // Self-consistency: a glaze over a ground of its own opaque colour is
      // unchanged at a finite thickness — pins the layering equation itself.
      final onOwnGround =
          glazedReflectance(glaze: glaze, thickness: xFinite, ground: opaque);
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        expect(onOwnGround[i], closeTo(opaque[i], 1e-5),
            reason: 'layering over an identical-reflectance ground is a no-op');
      }
    }, tags: 'stretch', skip: ac('AC-26'));

    test('AC-27 · TestAC27_Metamerism: illuminant-fragile matches are flagged '
        'with a metamerism index', () {
      // Un-pended by STRETCH-3 (G-7 ✅ Build STRETCH). Driven through the frozen
      // metamerism API `assessMetamerism` (design §9), public surface only.
      //
      // The two recipes are built as reflectance spectra over the SAME target:
      //   A (robust)  = the target spectrum itself — a spectral (non-metameric)
      //                 match that holds under every light.
      //   B (fragile) = the target plus a METAMERIC BLACK δ — a perturbation
      //                 that leaves the D65 tristimulus unchanged (so B matches
      //                 the target exactly under D65) but shifts the colour
      //                 under a warmer light. δ is built using the PUBLIC
      //                 `spectrumToColour` only: its XYZ is linear in the
      //                 spectrum, so impulse spectra recover the three XYZ weight
      //                 rows, and δ is the component of a seed perturbation
      //                 orthogonal to all three (Gram–Schmidt) — hence Mδ = 0.
      final target =
          Float32List.fromList(List<double>.filled(CanonicalGrid.bins, 0.5));
      final delta = _metamericBlack(
          List<double>.generate(CanonicalGrid.bins, (i) => math.sin(i * 0.9) * 0.45));
      final fragileRecipe = Float32List(CanonicalGrid.bins);
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        fragileRecipe[i] = target[i] + delta[i];
      }

      // Given checks.
      // The fixture genuinely provides two distinct illuminants, so the test is
      // actually multi-illuminant (rejects a one-light evaluation at the source).
      expect(illuminants.d65.length, CanonicalGrid.bins);
      expect(illuminants.warm.length, CanonicalGrid.bins);
      var sawIlluminantDifference = false;
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        if ((illuminants.d65[i] - illuminants.warm[i]).abs() > 1e-6) {
          sawIlluminantDifference = true;
        }
      }
      expect(sawIlluminantDifference, isTrue,
          reason: 'D65 and the warm studio illuminant must differ');
      // B is a genuine, physical SECOND recipe: a valid reflectance in (0,1]
      // that is spectrally different from the target (not a copy of recipe A).
      var sawSpectralDeparture = false;
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        expect(fragileRecipe[i], greaterThan(0.0));
        expect(fragileRecipe[i], lessThanOrEqualTo(1.0));
        if ((fragileRecipe[i] - target[i]).abs() > 1e-3) {
          sawSpectralDeparture = true;
        }
      }
      expect(sawSpectralDeparture, isTrue,
          reason: 'the fragile recipe must differ spectrally from the target');

      // WHEN each recipe is evaluated under D65 and a warm studio illuminant.
      final robust = assessMetamerism(
        target: target,
        candidate: target,
        referenceIlluminant: illuminants.d65,
        testIlluminant: illuminants.warm,
      );
      final fragile = assessMetamerism(
        target: target,
        candidate: fragileRecipe,
        referenceIlluminant: illuminants.d65,
        testIlluminant: illuminants.warm,
      );

      // Given check (the scenario's "match a target equally under D65"): both
      // recipes match the target under D65 to within ΔE00 1e-3, and equally so —
      // the metameric black makes B's D65 match as perfect as A's spectral one.
      expect(robust.deltaE00Reference, lessThan(1e-3),
          reason: 'the spectral match is exact under D65');
      expect(fragile.deltaE00Reference, lessThan(1e-3),
          reason: 'the metamer matches the target under D65');
      expect((fragile.deltaE00Reference - robust.deltaE00Reference).abs(),
          lessThan(1e-3),
          reason: 'the two recipes must match the target EQUALLY under D65');

      // THEN the recipe whose match degrades under the warm studio illuminant is
      // assigned the higher metamerism index …
      expect(fragile.index, greaterThan(robust.index),
          reason: 'the degrading recipe must get the higher metamerism index');
      // … and the engine warns that that match is illuminant-fragile, while the
      // robust spectral match is NOT flagged (a control proving the flag can be
      // off — not everything is called fragile).
      expect(fragile.illuminantFragile, isTrue,
          reason: 'the degrading match must be flagged illuminant-fragile');
      expect(robust.illuminantFragile, isFalse,
          reason: 'the spectral match must not be flagged fragile');

      // REJECTS an index computed under one illuminant only. Under the reference
      // light ALONE the two recipes are indistinguishable (both match the target
      // to ~0), so the fragile recipe's positive index cannot come from the
      // reference render — it only appears once the warm light is applied. Made
      // decisive by evaluating B with the test light SET EQUAL to the reference:
      // a single-illuminant assessment yields index 0 and no warning, so an index
      // that ignored the test illuminant could never flag this match.
      final singleIlluminant = assessMetamerism(
        target: target,
        candidate: fragileRecipe,
        referenceIlluminant: illuminants.d65,
        testIlluminant: illuminants.d65,
      );
      expect(singleIlluminant.index, lessThan(1e-6),
          reason: 'under one illuminant the metamer shows no degradation');
      expect(singleIlluminant.illuminantFragile, isFalse,
          reason: 'a one-illuminant index cannot flag an illuminant-fragile '
              'match — the warning requires the second light');

      // CONTROL — the index is the *degradation* (test minus reference), not the
      // absolute test-light error. A recipe that matches the target POORLY but
      // in an illuminant-STABLE way (same spectral shape, uniformly darker) is a
      // bad match under BOTH lights equally: its mismatch does not grow under
      // the warm light, so it is NOT illuminant-fragile. This REJECTS an index
      // computed from the test illuminant alone (`index = ΔE_test`), the other
      // half of the AC's "one illuminant only" reject: such an index would be
      // large here and wrongly raise the fragility warning.
      final stableRecipe = Float32List(CanonicalGrid.bins);
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        stableRecipe[i] = target[i] * 0.7;
      }
      final stable = assessMetamerism(
        target: target,
        candidate: stableRecipe,
        referenceIlluminant: illuminants.d65,
        testIlluminant: illuminants.warm,
      );
      // Given check: it is a genuinely poor match under D65 …
      expect(stable.deltaE00Reference, greaterThan(5.0),
          reason: 'the stable control must match the target poorly under D65');
      // … and its test-light error is large too — large enough that a test-only
      // index would exceed the fragility threshold and raise the warning.
      expect(stable.deltaE00Test, greaterThan(defaultMetamerismFragileThreshold),
          reason: 'the stable control is a poor match under the warm light too');
      // THEN the degradation is ~0 and the match is NOT flagged fragile: a bad
      // but illuminant-stable match must not trip the metamerism warning.
      expect(stable.index, lessThan(defaultMetamerismFragileThreshold),
          reason: 'an illuminant-stable mismatch does not degrade across lights');
      expect(stable.illuminantFragile, isFalse,
          reason: 'a poor but illuminant-stable match must NOT be flagged '
              'fragile — the index is degradation, not absolute test-light error');
    }, tags: 'stretch', skip: ac('AC-27'));
  });
}

/// The metameric-black component of [seed]: the part of the length-[bins]
/// perturbation that is orthogonal (under the plain dot product) to the three
/// XYZ weight rows of the D65 colour pipeline, so adding it to a spectrum leaves
/// that spectrum's D65 tristimulus unchanged. The weight rows are recovered
/// through the PUBLIC `spectrumToColour` alone: its XYZ is linear in the input,
/// so `spectrumToColour(eᵢ).xyz` is the i-th column of the XYZ matrix, i.e. the
/// weight each row gives bin i. Gram–Schmidt removes the seed's components along
/// those three rows.
List<double> _metamericBlack(List<double> seed) {
  const n = CanonicalGrid.bins;
  final rows = <List<double>>[
    List<double>.filled(n, 0),
    List<double>.filled(n, 0),
    List<double>.filled(n, 0),
  ];
  for (var i = 0; i < n; i++) {
    final e = Float32List(n);
    e[i] = 1.0;
    final xyz = spectrumToColour(e).xyz;
    rows[0][i] = xyz.x;
    rows[1][i] = xyz.y;
    rows[2][i] = xyz.z;
  }
  double dot(List<double> a, List<double> b) {
    var s = 0.0;
    for (var i = 0; i < n; i++) {
      s += a[i] * b[i];
    }
    return s;
  }

  // Orthonormalize the three rows.
  final basis = <List<double>>[];
  for (final row in rows) {
    final v = List<double>.from(row);
    for (final b in basis) {
      final p = dot(v, b);
      for (var i = 0; i < n; i++) {
        v[i] -= p * b[i];
      }
    }
    final norm = math.sqrt(dot(v, v));
    for (var i = 0; i < n; i++) {
      v[i] /= norm;
    }
    basis.add(v);
  }
  // Remove the seed's components along the basis → Mδ = 0.
  final delta = List<double>.from(seed);
  for (final b in basis) {
    final p = dot(delta, b);
    for (var i = 0; i < n; i++) {
      delta[i] -= p * b[i];
    }
  }
  return delta;
}

/// A ~15-paint single-medium palette for the performance budget (AC-20), built
/// by cloning the synthetic acrylic paints under distinct ids. Caller-supplied
/// input: the search size is what the AC times, not the specific colours.
List<Pigment> _fifteenPaintPalette() {
  final base = PigmentTable.load(Medium.acrylic).pigments;
  return <Pigment>[
    for (var i = 0; i < 15; i++)
      _rename(base[i % base.length], 'perf.paint_$i'),
  ];
}

/// [base] re-identified under a new [id] (same K,S, medium and other fields).
Pigment _rename(Pigment base, String id) => Pigment(
      id: id,
      name: base.name,
      pigmentIndex: base.pigmentIndex,
      medium: base.medium,
      k: base.k,
      s: base.s,
      opacity: base.opacity,
      provenance: base.provenance,
      sourceRef: base.sourceRef,
    );

/// [base] re-tagged with a new [provenance] tier (same identity and K,S) — the
/// honesty-tier input a recipe's provenance is derived from (AC-24).
Pigment _retag(Pigment base, Provenance provenance) => Pigment(
      id: base.id,
      name: base.name,
      pigmentIndex: base.pigmentIndex,
      medium: base.medium,
      k: base.k,
      s: base.s,
      opacity: base.opacity,
      provenance: provenance,
      sourceRef: base.sourceRef,
    );

/// The index of the recipe in [recipes] whose parts match [target]'s, or -1.
int _indexOfRecipe(List<Recipe> recipes, Recipe target) {
  for (var i = 0; i < recipes.length; i++) {
    if (_partsEqual(recipes[i].parts, target.parts)) return i;
  }
  return -1;
}

/// The index of the recipe in [recipes] that uses exactly the paint ids [ids],
/// or -1. The AC-22 constructed tie locates a recipe by its paint SET, not its
/// fitted fractions: identical-reflectance twins mix to one colour at any ratio,
/// so the solver keeps arbitrary (equally-good) shares for such a subset.
int _indexOfRecipeByIds(List<Recipe> recipes, Set<String> ids) {
  for (var i = 0; i < recipes.length; i++) {
    if (recipes[i].parts.keys.toSet().length == ids.length &&
        recipes[i].parts.keys.toSet().containsAll(ids)) {
      return i;
    }
  }
  return -1;
}

/// An identical-reflectance acrylic twin carrying [k] and [s] under [id] — the
/// AC-22 constructed tie builds two groups of these so each group predicts one
/// colour at any paint count (design §4.3 two-constant mixing).
Pigment _twin(String id, Spectrum k, Spectrum s) => Pigment(
      id: id,
      name: id,
      pigmentIndex: 'PW6',
      medium: Medium.acrylic,
      k: k,
      s: s,
      opacity: 0.5,
      provenance: Provenance.estimated,
      sourceRef: 'synthetic:ac22-tie-$id',
    );

/// A flat spectrum at [value] across the canonical grid.
Spectrum _flat(double value) =>
    Float32List.fromList(List<double>.filled(CanonicalGrid.bins, value));

/// A smooth absorption bump: [floor] + [height]·gaussian peaking at [peakBin].
Spectrum _bump({
  required int peakBin,
  required double floor,
  required double height,
}) {
  final out = Float32List(CanonicalGrid.bins);
  for (var i = 0; i < CanonicalGrid.bins; i++) {
    final d = (i - peakBin) / 6.0;
    out[i] = floor + height * math.exp(-d * d);
  }
  return out;
}

/// Order-independent, tolerant equality for two parts maps.
bool _partsEqual(Map<String, double> a, Map<String, double> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    final other = b[e.key];
    if (other == null || (other - e.value).abs() > 1e-9) return false;
  }
  return true;
}

/// A matcher asserting a parts map equals [expected] key-for-key within 1e-9.
Matcher _partsCloseTo(Map<String, double> expected) => predicate<Object?>(
      (actual) => actual is Map<String, double> && _partsEqual(actual, expected),
      'parts equal $expected within 1e-9',
    );
