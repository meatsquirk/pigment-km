import '../types/pigment.dart';
import '../types/provenance.dart';

/// Derives the honesty tier of a solved recipe from the pigments it is built
/// from (SI D9 / AC-24).
///
/// A recipe is **no stronger than its weakest input**: it leans on whatever its
/// least-trustworthy paint leans on. The source-honesty order used here, weakest
/// to strongest, is
///
///   estimated  <  calculated  <  measured  <  confirmed
///
/// - [Provenance.estimated]: inferred without measured backing — any estimated
///   paint drags the whole recipe down to estimated.
/// - [Provenance.calculated]: derived from measured pigment data through the
///   model. A recipe from the shipped measured dataset is Calculated — a
///   third-party dataset alone never reaches Measured (D-8).
/// - [Provenance.measured]: measured directly from the user's own physical tube.
///   A recipe stays Measured only when **every** paint is the user's own measured
///   tube; the moment it leans on a Calculated dataset paint it is Calculated.
/// - [Provenance.confirmed]: a measured result the user verified — strongest, so
///   it never pulls a recipe down.
///
/// An empty pigment set has nothing to back it, so it is [Provenance.estimated].
Provenance recipeProvenance(Iterable<Pigment> pigments) {
  Provenance? weakest;
  for (final pigment in pigments) {
    if (weakest == null ||
        _sourceStrength(pigment.provenance) < _sourceStrength(weakest)) {
      weakest = pigment.provenance;
    }
  }
  return weakest ?? Provenance.estimated;
}

/// The source-honesty rank of [p] (see [recipeProvenance]); larger is stronger.
int _sourceStrength(Provenance p) {
  switch (p) {
    case Provenance.estimated:
      return 0;
    case Provenance.calculated:
      return 1;
    case Provenance.measured:
      return 2;
    case Provenance.confirmed:
      return 3;
  }
}
