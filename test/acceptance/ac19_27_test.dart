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

      // Find an adjacent pair that TIES on ΔE00 in the plain ranking but differs
      // in chroma — the only case the penalty is defined to reorder. (SOLVER/
      // TUNE-2 augmentation adds a constructed guaranteed equal-ΔE00 2-vs-3-paint
      // tie; this checks every tie the solve naturally produces.)
      var sawTie = false;
      for (var i = 1; i < plain.length; i++) {
        if ((plain[i].deltaE00 - plain[i - 1].deltaE00).abs() < 1e-9) {
          final loC = plain[i].colour.oklch.c < plain[i - 1].colour.oklch.c
              ? plain[i]
              : plain[i - 1];
          final hiC = identical(loC, plain[i]) ? plain[i - 1] : plain[i];
          if ((hiC.colour.oklch.c - loC.colour.oklch.c).abs() < 1e-9) continue;
          sawTie = true;
          // WHEN the solver ranks the SAME pair with the penalty enabled …
          final posLo = _indexOfRecipe(penalised, loC);
          final posHi = _indexOfRecipe(penalised, hiC);
          expect(posLo, isNonNegative);
          expect(posHi, isNonNegative);
          // THEN the lower-chroma recipe of the tie ranks ahead of the higher.
          // Rejects a penalty with no effect (order unchanged) and one that
          // always dominates ΔE00 (it would also reorder the non-tie pairs,
          // which the penalty-off monotonicity check above forbids).
          expect(posLo, lessThan(posHi),
              reason: 'the penalty must rank the lower-chroma tie member first');
        }
      }
      // See the AC-22 augmentation row (TUNE-2): the constructed guaranteed tie
      // lets this assertion fire deterministically.
      expect(sawTie, isTrue,
          reason: 'a ΔE00 tie with a chroma gap must exist to exercise the '
              'penalty — TUNE-2 constructs one (augmentation)');
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
      // SCOPE GATE (G-7 open): finite-thickness glazing (design §3.4) is an
      // optional S6 scenario. Its public layering API is intentionally NOT frozen
      // until G-7 approves the scope and STRETCH-2 adds it (Option-A-style). This
      // placeholder fails here on its scope precondition; STRETCH-2 replaces the
      // body with the scenario below, driven through the frozen layering API:
      //   GIVEN  a mixture glazed at a finite film thickness X over a ground of
      //          known reflectance Rg (assert X finite & Rg a valid spectrum).
      //   WHEN   its layered reflectance is computed.
      //   THEN   it follows the §3.4 finite-thickness KM layering equation, and
      //          as X → ∞ the result approaches the opaque-form reflectance
      //          (CONTROL: a large X ≈ `reflectanceOf` of the opaque mix).
      //   REJECTS reusing the opaque form (ignoring thickness/ground).
      expect(_stretchScopeApproved, isTrue,
          reason: 'AC-26 finite-thickness glazing is @stretch — gated behind '
              'G-7; STRETCH-2 freezes the layering API and un-pends this');
    }, tags: 'stretch', skip: ac('AC-26'));

    test('AC-27 · TestAC27_Metamerism: illuminant-fragile matches are flagged '
        'with a metamerism index', () {
      // SCOPE GATE (G-7 open): multi-illuminant metamerism (design §9) is an
      // optional S6 scenario. Its public metamerism-index + illuminant-fragility
      // API is intentionally NOT frozen until G-7 approves the scope and
      // STRETCH-3 adds it. The `illuminants` fixture (d65 + warm) is already
      // present for it. This placeholder fails here on its scope precondition;
      // STRETCH-3 replaces the body with the scenario below:
      //   GIVEN  two recipes that match a target equally under D65 (assert equal
      //          D65 ΔE00).
      //   WHEN   they are evaluated under D65 and a warm studio illuminant.
      //   THEN   the recipe whose match degrades under the studio illuminant is
      //          assigned the higher metamerism index, and the engine warns that
      //          that match is illuminant-fragile.
      //   REJECTS an index computed under one illuminant only.
      expect(_stretchScopeApproved, isTrue,
          reason: 'AC-27 metamerism is @stretch — gated behind G-7; STRETCH-3 '
              'freezes the multi-illuminant API and un-pends this');
    }, tags: 'stretch', skip: ac('AC-27'));
  });
}

/// Whether the optional S6 (STRETCH) scope has been approved at G-7. False until
/// the gate resolves; STRETCH-2/3 flip the real behaviour on once it does.
const bool _stretchScopeApproved = false;

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
