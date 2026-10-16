/// A paint medium. A pigment belongs to exactly one medium and a recipe never
/// spans media (design §4.3).
enum Medium { acrylic, oil }

/// The per-medium drying shift applied by the wet/dry toggle (design §7 lever 3).
///
/// Expressed in CIE L*C*h terms: [lightnessDelta] is the change in L* from wet to
/// dry (negative = darker), [chromaDelta] the change in C*, and [hueDeltaDeg] the
/// hue rotation in degrees. The zero transform leaves a colour unchanged.
class WetDryTransform {
  const WetDryTransform({
    this.lightnessDelta = 0,
    this.chromaDelta = 0,
    this.hueDeltaDeg = 0,
  });

  /// The identity transform: wet and dry are the same colour.
  static const WetDryTransform none = WetDryTransform();

  final double lightnessDelta;
  final double chromaDelta;
  final double hueDeltaDeg;

  @override
  bool operator ==(Object other) =>
      other is WetDryTransform &&
      other.lightnessDelta == lightnessDelta &&
      other.chromaDelta == chromaDelta &&
      other.hueDeltaDeg == hueDeltaDeg;

  @override
  int get hashCode => Object.hash(lightnessDelta, chromaDelta, hueDeltaDeg);
}

/// Everything that changes between media (design §4.3, §10): the Saunderson
/// surface-reflection constants [k1], [k2] and the per-medium drying shift
/// [wetDry]. The grid and the CIE/D65 weights are shared (canonical), not here.
class MediumConfig {
  const MediumConfig({
    required this.medium,
    required this.k1,
    required this.k2,
    this.wetDry = WetDryTransform.none,
  });

  final Medium medium;
  final double k1;
  final double k2;
  final WetDryTransform wetDry;

  @override
  bool operator ==(Object other) =>
      other is MediumConfig &&
      other.medium == medium &&
      other.k1 == k1 &&
      other.k2 == k2 &&
      other.wetDry == wetDry;

  @override
  int get hashCode => Object.hash(medium, k1, k2, wetDry);
}
