import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';
// recipeProvenance is engine-internal (read through Recipe.provenance in the
// public API); the unit tests reach it directly to pin every tier branch.
import 'package:pigment_km/src/engine/provenance.dart' show recipeProvenance;
import 'package:test/test.dart';

/// A throwaway paint carrying only the [provenance] tier under test — the
/// derivation reads nothing else. K/S are flat, non-zero spectra on the grid.
Pigment _paint(String id, Provenance provenance) => Pigment(
      id: id,
      name: id,
      pigmentIndex: 'PX',
      medium: Medium.acrylic,
      k: Float32List.fromList(List<double>.filled(CanonicalGrid.bins, 0.1)),
      s: Float32List.fromList(List<double>.filled(CanonicalGrid.bins, 0.5)),
      opacity: 0.5,
      provenance: provenance,
      sourceRef: 'test',
    );

void main() {
  group('recipeProvenance — a recipe is no stronger than its weakest input', () {
    test('an empty pigment set has nothing to back it → estimated', () {
      expect(recipeProvenance(const <Pigment>[]), Provenance.estimated);
    });

    test('all paints from the measured dataset (calculated) → Calculated', () {
      final palette = <Pigment>[
        _paint('a', Provenance.calculated),
        _paint('b', Provenance.calculated),
      ];
      expect(recipeProvenance(palette), Provenance.calculated);
    });

    test("only the user's own measured tubes → Measured", () {
      final palette = <Pigment>[
        _paint('a', Provenance.measured),
        _paint('b', Provenance.measured),
      ];
      expect(recipeProvenance(palette), Provenance.measured);
    });

    test('a measured tube mixed with a calculated dataset paint → Calculated '
        '(it now leans on the dataset)', () {
      // weakest-first: measured(2) then calculated(1) — the later paint is
      // weaker, so the running weakest is replaced (the `<` branch is true).
      expect(
        recipeProvenance(<Pigment>[
          _paint('tube', Provenance.measured),
          _paint('dataset', Provenance.calculated),
        ]),
        Provenance.calculated,
      );
      // strongest-first: calculated(1) then measured(2) — the later paint is
      // stronger, so the running weakest is kept (the `<` branch is false).
      expect(
        recipeProvenance(<Pigment>[
          _paint('dataset', Provenance.calculated),
          _paint('tube', Provenance.measured),
        ]),
        Provenance.calculated,
      );
    });

    test('any estimated paint drags the recipe down to Estimated', () {
      expect(
        recipeProvenance(<Pigment>[
          _paint('tube', Provenance.measured),
          _paint('guess', Provenance.estimated),
        ]),
        Provenance.estimated,
      );
    });

    test('a confirmed paint is strongest — it never pulls a recipe down', () {
      // all confirmed → confirmed (covers the confirmed strength branch)
      expect(
        recipeProvenance(<Pigment>[_paint('v', Provenance.confirmed)]),
        Provenance.confirmed,
      );
      // confirmed + measured → measured (confirmed does not weaken it)
      expect(
        recipeProvenance(<Pigment>[
          _paint('v', Provenance.confirmed),
          _paint('tube', Provenance.measured),
        ]),
        Provenance.measured,
      );
    });
  });
}
