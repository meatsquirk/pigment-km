import '../types/recipe.dart';

/// Design §7 lever 2 (D-10) — the natural-colour chroma penalty.
///
/// A naturalistic image is built from muted, low-chroma mixtures; two recipes
/// that match the target equally well are not equally natural, and the more
/// saturated one reads as garish. λ_natural is the weight of a small chroma
/// regularizer added to a recipe's ΔE00 match cost (see [chromaPenalizedCost]),
/// so that on a ΔE00 tie the lower-chroma, more muted recipe is preferred.
///
/// It is deliberately tiny. `λ·C*` is dwarfed by any ΔE00 gap a viewer could
/// see, so it never trades away match accuracy: for two recipes whose ΔE00
/// differ by more than `λ·ΔC*` the cost is governed by ΔE00 alone (the penalty
/// is *off* in the raw ranking), and it reorders only recipes whose match
/// distances are equal or within numerical noise — a pure tie-break. At
/// `λ = 1e-6`, with OKLCh chroma bounded well under 1, the largest nudge is
/// below 1e-6 ΔE00, far under the ~1 ΔE00 just-noticeable difference, yet still
/// decisively larger than the sub-nanometre spread of a genuine ΔE00 tie.
const double naturalChromaPenalty = 1e-6;

/// The chroma-penalized match cost of [recipe] under weight [lambda]: the
/// recipe's ΔE00 to the target plus `lambda · C*`, where C* is the OKLCh chroma
/// of the recipe's predicted colour — the same chroma measure the natural-colour
/// ceiling uses (design §7).
///
/// With `lambda == 0` this is exactly [Recipe.deltaE00], so a solve with the
/// penalty disabled ranks by ΔE00 alone and the penalty leaves the raw ranking
/// untouched. With `lambda > 0` an otherwise-tied pair is ordered lower-chroma
/// first, because the lower C* yields the smaller cost.
double chromaPenalizedCost(Recipe recipe, double lambda) =>
    recipe.deltaE00 + lambda * recipe.colour.oklch.c;
