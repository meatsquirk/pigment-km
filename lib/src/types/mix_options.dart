/// Options controlling an inverse solve (design §6.2, §7; SI NFR).
class MixOptions {
  const MixOptions({
    this.maxPaints = 4,
    this.topK = 5,
    this.gamutThreshold = 5.0,
    this.chromaPenalty = true,
    this.wet = true,
  });

  /// The most pigments any single recipe may combine.
  final int maxPaints;

  /// How many ranked recipes to return (best-first by ΔE00).
  final int topK;

  /// The ΔE00 ceiling at or below which a target counts as in-gamut; a best
  /// recipe worse than this is flagged out-of-gamut (design §6.2; SI NFR ≤ 5).
  final double gamutThreshold;

  /// When true, a natural-colour chroma penalty breaks ΔE00 ties toward the more
  /// muted recipe (design §7 lever 2).
  final bool chromaPenalty;

  /// Predict in the wet state when true, the dry state when false (design §7
  /// lever 3).
  final bool wet;

  @override
  bool operator ==(Object other) =>
      other is MixOptions &&
      other.maxPaints == maxPaints &&
      other.topK == topK &&
      other.gamutThreshold == gamutThreshold &&
      other.chromaPenalty == chromaPenalty &&
      other.wet == wet;

  @override
  int get hashCode =>
      Object.hash(maxPaints, topK, gamutThreshold, chromaPenalty, wet);
}
