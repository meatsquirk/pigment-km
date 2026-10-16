import 'colour_value.dart';
import 'medium.dart';
import 'provenance.dart';

/// A solved mixing recipe (design §6.2, §10).
///
/// [parts] maps a pigment id to its volume fraction; the fractions sum to 1 and
/// belong to a single [medium] (a recipe never spans media). [colour] is the
/// predicted colour, [deltaE00] its distance to the target, [provenance] the
/// honesty tier, [outOfGamut] whether the target is unreachable (in which case
/// the recipe is the honest nearest, never reported as a match), and [verdict] a
/// plain-language summary.
class Recipe {
  const Recipe({
    required this.medium,
    required this.parts,
    required this.colour,
    required this.deltaE00,
    required this.provenance,
    required this.outOfGamut,
    required this.verdict,
  });

  final Medium medium;

  /// Pigment id → volume fraction, summing to 1.
  final Map<String, double> parts;

  /// The predicted colour of this mixture.
  final ColourValue colour;

  /// CIE ΔE00 from [colour] to the solve target.
  final double deltaE00;

  final Provenance provenance;

  /// True when the target lies outside what this palette can mix; the recipe is
  /// then the honest nearest approach, flagged — never a claimed match.
  final bool outOfGamut;

  /// Plain-language description of the match quality.
  final String verdict;

  @override
  bool operator ==(Object other) =>
      other is Recipe &&
      other.medium == medium &&
      _partsEqual(other.parts, parts) &&
      other.colour == colour &&
      other.deltaE00 == deltaE00 &&
      other.provenance == provenance &&
      other.outOfGamut == outOfGamut &&
      other.verdict == verdict;

  @override
  int get hashCode => Object.hash(
        medium,
        _partsHash(parts),
        colour,
        deltaE00,
        provenance,
        outOfGamut,
        verdict,
      );
}

/// Order-independent equality for two parts maps.
bool _partsEqual(Map<String, double> a, Map<String, double> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

/// Order-independent hash for a parts map, consistent with [_partsEqual].
int _partsHash(Map<String, double> parts) => Object.hashAllUnordered(
      parts.entries.map((e) => Object.hash(e.key, e.value)),
    );
