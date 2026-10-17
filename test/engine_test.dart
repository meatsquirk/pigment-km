import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';
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

void _behavesAsUnimplementedStub(MixingEngine engine) {
  expect(() => engine.forward(const {'a': 1.0}), throwsUnimplementedError);
  expect(
    () => engine.inverse(_target, const [], const MixOptions()),
    throwsUnimplementedError,
  );
  expect(() => engine.reflectanceOf(const {'a': 1.0}), throwsUnimplementedError);
}

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

  test('SpectralBaselineEngine implements MixingEngine and stubs throw', () {
    const engine = SpectralBaselineEngine();
    expect(engine, isA<MixingEngine>());
    _behavesAsUnimplementedStub(engine);
  });
}
