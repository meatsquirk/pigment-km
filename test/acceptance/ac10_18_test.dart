import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

import 'harness/harness.dart';

/// Acceptance band 2 (ITEST-3): AC-10 … AC-18.
///
/// One pending integration test per AC, driven entirely through the package's
/// public surface. Each test calls [ac] in its `skip:` argument so it is skipped
/// in the default run and executed under `PIGMENT_KM_RUN_PENDING=true` (the red
/// baseline), where it must fail for the right reason — on a Then, on a When
/// (the behaviour throwing its documented `UnimplementedError`), or on a Given
/// precondition naming the owning phase — until that behaviour phase lands.
///
/// Covered: AC-10 masstone–tint (DATA-4), AC-11 attribution + provenance
/// (DATA-7), AC-12 forward fidelity (FORWARD-3), AC-13 desaturation (FORWARD-4),
/// AC-14 volume normalization (FORWARD-2), AC-15 ranked/prefer-fewer (SOLVER-3),
/// AC-16 palette-only (SOLVER-2), AC-17 in-gamut ≤ 5 (SOLVER-6), AC-18
/// out-of-gamut (SOLVER-4). The masstone–tint backend `deriveKsFromMasstoneTint`
/// is the public stub added in ITEST-3 (Option A), throwing a documented
/// `UnimplementedError` naming DATA-4 until built.
void main() {
  group('DATA — masstone–tint and attribution', () {
    test('AC-10 · TestAC10_MasstoneTint: K and S are derived from a masstone '
        'and tint series', () {
      // GIVEN a pigment's masstone reflectance and a tint series with white at
      // known concentrations. Built from a KNOWN (K,S) and a known white via the
      // test's OWN independent two-constant KM reference, so a correct
      // derivation must recover a (K,S) that reproduces every tint.
      final trueK = _bump(peakBin: 14, floor: 0.05, height: 0.9);
      final trueS = _flat(0.3);
      final whiteK = _flat(0.05);
      final whiteS = _flat(1.0); // S_w ≡ 1 (design §4.4).

      final concentrations = <double>[0.25, 0.5, 0.75];
      final masstone = _tintReflectance(1.0, trueK, trueS, whiteK, whiteS);
      final tints = <Tint>[
        for (final c in concentrations)
          (
            pigmentFraction: c,
            reflectance: _tintReflectance(c, trueK, trueS, whiteK, whiteS),
          ),
      ];
      // Given checks: at least two tints, each at a known concentration in
      // (0, 1), and the masstone is on the canonical grid.
      expect(tints.length, greaterThanOrEqualTo(2));
      for (final t in tints) {
        expect(t.pigmentFraction, greaterThan(0.0));
        expect(t.pigmentFraction, lessThan(1.0));
        expect(t.reflectance, hasLength(CanonicalGrid.bins));
      }
      expect(masstone, hasLength(CanonicalGrid.bins));

      // WHEN K and S are derived per wavelength by least squares across tints.
      final derived = deriveKsFromMasstoneTint(
        masstone: masstone,
        tints: tints,
        whiteK: whiteK,
        whiteS: whiteS,
      );

      // THEN the derived K,S reproduce every tint's measured reflectance within
      // tolerance (re-predicted through the same independent KM reference) …
      expect(derived.k, hasLength(CanonicalGrid.bins));
      expect(derived.s, hasLength(CanonicalGrid.bins));
      for (final t in tints) {
        final predicted = _tintReflectance(
            t.pigmentFraction, derived.k, derived.s, whiteK, whiteS);
        for (var i = 0; i < CanonicalGrid.bins; i++) {
          expect(predicted[i], closeTo(t.reflectance[i], 1e-3),
              reason: 'derived K,S must reproduce the tint at fraction '
                  '${t.pigmentFraction}, bin $i');
        }
      }
      // … and the masstone itself.
      final predictedMasstone =
          _tintReflectance(1.0, derived.k, derived.s, whiteK, whiteS);
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        expect(predictedMasstone[i], closeTo(masstone[i], 1e-3),
            reason: 'derived K,S must reproduce the masstone at bin $i');
      }
      // Rejects fitting the masstone alone (the opaque reflectance fixes only
      // K/S, not K and S separately — an arbitrary S scale that matches the
      // masstone would mispredict the white-diluted tints) and rejects ignoring
      // the white's (K_w,S_w) (the tint reflectances depend on them).
    }, skip: ac('AC-10'));

    test('AC-11 · TestAC11_Attribution: shipped data carries its licence '
        'attribution and correct provenance', () {
      // GIVEN the built package tree: the LICENSE and NOTICE files exist
      // (resolved relative to the package root, the `dart test` working dir).
      final license = File('LICENSE');
      final notice = File('NOTICE');
      expect(license.existsSync(), isTrue, reason: 'a LICENSE file must ship');
      expect(notice.existsSync(), isTrue, reason: 'a NOTICE file must ship');

      // WHEN the package and its data notices are inspected.
      final licenseText = license.readAsStringSync();
      final noticeText = notice.readAsStringSync();

      // THEN the package source is licensed MIT …
      expect(licenseText, contains('MIT License'));
      // … the MPI oil data carries its CC BY 4.0 attribution naming the authors
      // and stating the changes made (CC BY 4.0 — clear now; design §13.4) …
      expect(noticeText, contains('CC BY 4.0'));
      expect(noticeText, contains('Asadi'));
      expect(noticeText, contains('Babaei'));
      expect(noticeText, contains('Seidel'));
      expect(noticeText.toLowerCase(), contains('changes'));
      // … a Golden/RIT acrylic attribution is present …
      expect(noticeText, contains('RIT'));
      // … and every synthetic placeholder paint is honestly tagged: estimated,
      // with a `synthetic:` source ref — never passed off as measured/calculated.
      for (final medium in Medium.values) {
        for (final p in PigmentTable.load(medium).pigments) {
          expect(p.provenance, Provenance.estimated,
              reason: 'synthetic placeholder paints must be tagged estimated');
          expect(p.sourceRef, startsWith('synthetic:'));
        }
      }

      // PRECONDITION (names DATA-7 / G-3): the finalized Golden/RIT attribution
      // wording and the "each paint's provenance reflects the source it came
      // from" Then for the REAL data need the licensed acrylic data on disk.
      // Until G-3/DATA-5 the acrylic table is the synthetic placeholder, so the
      // real-source provenance Then below cannot be exercised. DATA-7 augments
      // the acrylic NOTICE wording and flips this precondition.
      expect(acrylicPublishedPlaceholder.isReal, isTrue,
          reason: 'AC-11 asserts the finalized Golden/RIT attribution + '
              'provenance-per-real-source on the real data — G-3/DATA-5/DATA-7');

      // THEN each real paint's provenance reflects its source: paints derived
      // from measured Golden/RIT data are Calculated (not Estimated/Measured).
      for (final p in givenAcrylicTable().pigments) {
        expect(p.provenance, Provenance.calculated,
            reason: 'paints derived from measured data must be Calculated');
      }
    }, skip: ac('AC-11'));
  });

  group('FORWARD — the forward model', () {
    test('AC-12 · TestAC12_ForwardFidelity: the forward model predicts a known '
        "mixture's colour", () {
      final engine = customEngine();

      // GIVEN a mixture of measured paints at known volume fractions with a
      // published measured colour. PRECONDITION — real-data fidelity: it needs
      // the measured mixtures on disk (G-3 acrylic / G-4 oil). Until
      // FORWARD-3 the measuredMixtures fixture is a placeholder (isReal=false).
      expect(measuredMixturesPlaceholder.isReal, isTrue,
          reason: 'AC-12 needs real measured mixtures with published colours — '
              'G-3/G-4 → FORWARD-3');
      final mixtures = measuredMixturesPlaceholder.mixtures!;
      expect(mixtures, isNotEmpty);

      for (final m in mixtures) {
        expect(m.parts.values.fold<double>(0, (a, b) => a + b),
            closeTo(1.0, 1e-9),
            reason: 'the mixture volume fractions must be known and sum to 1');

        // WHEN the engine predicts the mixture's colour.
        final predicted = engine.forward(m.parts);

        // THEN the prediction matches the dataset's measured colour ≤ ΔE00 5.
        // Rejects a single-constant forward that ignores S (it would drift on a
        // real two-constant mixture). FORWARD-3 populates the measured mixtures.
        expect(deltaE00(predicted.xyz, m.colour.xyz), lessThanOrEqualTo(5.0),
            reason: 'two-constant forward must predict the measured mixture '
                'within ΔE00 ≤ 5');
      }
    }, skip: ac('AC-12'));

    test('AC-13 · TestAC13_Desaturation: mixing two real pigments desaturates '
        'the way real paint does', () {
      final engine = customEngine();
      final blue = _paint('acrylic.phthalo_blue');
      final red = _paint('acrylic.naphthol_red');

      // GIVEN two chromatic measured paints of different hue — assert each pure
      // paint is chromatic and the two hues differ.
      final pureBlue = engine.forward({blue.id: 1.0});
      final pureRed = engine.forward({red.id: 1.0});
      expect(pureBlue.oklch.c, greaterThan(0.04),
          reason: 'the blue must be chromatic');
      expect(pureRed.oklch.c, greaterThan(0.04),
          reason: 'the red must be chromatic');
      expect(hueDiffDeg(pureBlue.oklch.h, pureRed.oklch.h), greaterThan(20.0),
          reason: 'the two paints must differ in hue');

      // WHEN they are mixed in equal volume …
      final kmMix = engine.forward({blue.id: 0.5, red.id: 0.5});
      // … and compared to a naive linear-RGB blend of the same two colours (the
      // per-channel midpoint in sRGB — what an RGB-space engine would produce).
      final rgbBlend = (
        r: (pureBlue.srgb.r + pureRed.srgb.r) / 2,
        g: (pureBlue.srgb.g + pureRed.srgb.g) / 2,
        b: (pureBlue.srgb.b + pureRed.srgb.b) / 2,
      );
      final rgbBlendChroma = srgbToOklch(rgbBlend).c;

      // THEN the KM mixture's chroma is lower than the naive RGB blend's —
      // real two-constant mixing greys out where an RGB blend stays vibrant.
      // Rejects an engine that blends in RGB (the natural-colour check).
      expect(kmMix.oklch.c, lessThan(rgbBlendChroma),
          reason: 'the KM mix must be more muted than a naive RGB blend');
    }, skip: ac('AC-13'));

    test('AC-14 · TestAC14_Normalize: volumes are normalized before mixing', () {
      final engine = customEngine();
      final white = _paint('acrylic.titanium_white');
      final blue = _paint('acrylic.phthalo_blue');

      // GIVEN parts-by-volume that do not sum to 1 (2:1 raw → sum 3).
      final raw = <String, double>{white.id: 2.0, blue.id: 1.0};
      final rawSum = raw.values.fold<double>(0, (a, b) => a + b);
      expect(rawSum, closeTo(3.0, 1e-12));
      expect((rawSum - 1.0).abs() > 0.5, isTrue,
          reason: 'the Given parts must not already sum to 1');
      // The same ratio normalized to sum 1.
      final normalized = <String, double>{white.id: 2 / 3, blue.id: 1 / 3};
      expect(normalized.values.fold<double>(0, (a, b) => a + b),
          closeTo(1.0, 1e-12));

      // WHEN the engine predicts the raw mixture.
      final rawResult = engine.forward(raw);
      final normResult = engine.forward(normalized);

      // THEN the raw result equals the normalized result — the parts are
      // normalized to sum 1 and map directly to the concentration weights.
      expect(deltaE00(rawResult.xyz, normResult.xyz), lessThan(1e-6),
          reason: 'parts must be normalized to Σ1 before mixing');
      // CONTROL: another scaling of the SAME ratio (6:3) also matches — rejects
      // an engine that uses the raw (unnormalized) weights.
      final scaled = engine.forward({white.id: 6.0, blue.id: 3.0});
      expect(deltaE00(scaled.xyz, normResult.xyz), lessThan(1e-6),
          reason: 'any scaling of the same ratio must give the same colour');
      // CONTROL: a DIFFERENT ratio gives a different colour — rejects an engine
      // that collapses every mixture to the same result.
      final otherRatio = engine.forward({white.id: 1.0, blue.id: 2.0});
      expect(deltaE00(otherRatio.xyz, normResult.xyz), greaterThan(1e-3),
          reason: 'a different ratio must change the predicted colour');
    }, skip: ac('AC-14'));
  });

  group('SOLVER — the inverse solver', () {
    test('AC-15 · TestAC15_RankedPreferFewer: the inverse solver returns ranked '
        'recipes preferring fewer paints', () {
      final engine = customEngine();
      final palette = synthPigments();
      // GIVEN a target colour and a declared palette of at least two paints.
      expect(palette.length, greaterThanOrEqualTo(2));
      final target = colourFromSrgb((r: 0.5, g: 0.47, b: 0.52));
      const opts = MixOptions(topK: 5);

      // WHEN the solver searches for recipes.
      final recipes = engine.inverse(target, palette, opts);

      // THEN it returns up to the requested number, best-first by ΔE00 …
      expect(recipes, isNotEmpty);
      expect(recipes.length, lessThanOrEqualTo(opts.topK));
      // … and at least two candidates, so the ordering assertion below is not
      // vacuous — a solver that returns a single unranked best recipe is
      // rejected here (this palette + topK=5 admits several recipes).
      expect(recipes.length, greaterThanOrEqualTo(2),
          reason: 'a ranked solve must return multiple candidates to order');
      for (var i = 1; i < recipes.length; i++) {
        expect(recipes[i].deltaE00, greaterThanOrEqualTo(recipes[i - 1].deltaE00),
            reason: 'recipes must be ordered best-first by ΔE00 — rejects an '
                'unstable or unsorted ranking');
      }
      // … each recipe is parts-by-volume summing to 1 …
      final paletteIds = palette.map((p) => p.id).toSet();
      for (final r in recipes) {
        expect(r.parts.values.fold<double>(0, (a, b) => a + b),
            closeTo(1.0, 1e-6),
            reason: 'each recipe must be parts-by-volume summing to 1');
        expect(r.parts.keys, everyElement(isIn(paletteIds)));
      }
      // … and when two recipes tie on ΔE00 the one using fewer paints ranks
      // first. (Augmented by SOLVER-3 with a constructed guaranteed 2-vs-3-paint
      // tie; here the rule is checked on any adjacent tie the solve produces.)
      for (var i = 1; i < recipes.length; i++) {
        if ((recipes[i].deltaE00 - recipes[i - 1].deltaE00).abs() < 1e-9) {
          expect(recipes[i - 1].parts.length,
              lessThanOrEqualTo(recipes[i].parts.length),
              reason: 'on a ΔE00 tie the fewer-paint recipe must rank first');
        }
      }
    }, skip: ac('AC-15'));

    test('AC-16 · TestAC16_PaletteOnly: recipes use only paints in the declared '
        'palette', () {
      final engine = customEngine();
      final all = synthPigments();
      final excluded = all.firstWhere((p) => p.id == 'acrylic.naphthol_red');
      // GIVEN a target and a palette that excludes a tempting paint (the red is
      // left out, though the target is reddish) — assert it is absent.
      final palette = all.where((p) => p.id != excluded.id).toList();
      final paletteIds = palette.map((p) => p.id).toSet();
      expect(paletteIds, isNot(contains(excluded.id)));
      expect(palette, isNotEmpty);
      final target = colourFromSrgb((r: 0.78, g: 0.33, b: 0.33));

      // WHEN the solver returns recipes.
      final recipes = engine.inverse(target, palette, const MixOptions());

      // THEN every paint in every returned recipe is a member of that palette —
      // rejects a solver that reaches into the full dataset (it would pull in
      // the excluded red to chase the reddish target).
      expect(recipes, isNotEmpty);
      for (final r in recipes) {
        for (final id in r.parts.keys) {
          expect(paletteIds, contains(id),
              reason: 'recipe paint "$id" is not in the declared palette');
        }
      }
    }, skip: ac('AC-16'));

    test('AC-17 · TestAC17_InGamut: an in-gamut target is matched within the '
        'recipe accuracy target', () {
      final engine = customEngine();
      final palette = synthPigments();
      // GIVEN a target reachable within the palette's gamut — a pale cool grey a
      // white+blue tint can reach. (SOLVER-6 confirms the exact reachable target;
      // G-6 adds held-out spectrophotometer validation evidence.)
      final target = colourFromSrgb((r: 0.72, g: 0.76, b: 0.86));
      const opts = MixOptions();

      // WHEN the solver returns its best recipe.
      final recipes = engine.inverse(target, palette, opts);
      expect(recipes, isNotEmpty);
      final best = recipes.first;

      // THEN the best recipe's ΔE00 to the target is at most 5 (SI NFR), and it
      // is not flagged out-of-gamut. Rejects a solver that stops early above 5.
      expect(best.deltaE00, lessThanOrEqualTo(opts.gamutThreshold),
          reason: 'an in-gamut target must be matched within ΔE00 ≤ 5');
      expect(best.outOfGamut, isFalse,
          reason: 'a reachable target must not be flagged out-of-gamut');
    }, skip: ac('AC-17'));

    test('AC-18 · TestAC18_OutOfGamut: an out-of-gamut target is flagged, never '
        'faked', () {
      final engine = customEngine();
      final palette = synthPigments(); // white, blue, red — no green primary.
      // GIVEN a target no mixture of the palette can reach: pure sRGB green, far
      // more chromatic than the muted synthetic palette can produce.
      const target = oogColour;
      expect(target.oklch.c, greaterThan(0.2),
          reason: 'the target must be highly chromatic (unreachable control)');

      // WHEN the solver returns its best recipe.
      final recipes = engine.inverse(target, palette, const MixOptions());
      expect(recipes, isNotEmpty);
      final best = recipes.first;

      // THEN the recipe is flagged out-of-gamut and carries its honest ΔE00
      // distance, and is never reported as a match. Rejects a solver that
      // returns the nearest mix unflagged (a false recipe).
      expect(best.outOfGamut, isTrue,
          reason: 'an unreachable target must be flagged out-of-gamut');
      expect(best.deltaE00, greaterThan(const MixOptions().gamutThreshold),
          reason: 'its honest ΔE00 must exceed the in-gamut ceiling (5)');
    }, skip: ac('AC-18'));
  });
}

/// The synthetic acrylic paint with the given [id] (through the public loader).
Pigment _paint(String id) => synthPigments().firstWhere((p) => p.id == id);

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

/// The test's OWN independent two-constant Kubelka–Munk reference (opaque form)
/// for a tint of a pigment ([kPig],[sPig]) with a white ([kWhite],[sWhite]) at
/// pigment volume fraction [frac]: mix K,S are the volume-weighted sums, and
/// `R∞ = 1 + x − √(x² + 2x)` for `x = Kmix/Smix`. Independent of the library's
/// own KM maths, so AC-10 checks a derivation against a trusted reference.
Spectrum _tintReflectance(
  double frac,
  Spectrum kPig,
  Spectrum sPig,
  Spectrum kWhite,
  Spectrum sWhite,
) {
  final out = Float32List(CanonicalGrid.bins);
  for (var i = 0; i < CanonicalGrid.bins; i++) {
    final k = frac * kPig[i] + (1 - frac) * kWhite[i];
    final s = frac * sPig[i] + (1 - frac) * sWhite[i];
    final x = k / s;
    out[i] = 1 + x - math.sqrt(x * x + 2 * x);
  }
  return out;
}
