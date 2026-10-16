import '../grid.dart';
import 'medium.dart';
import 'provenance.dart';

/// A single measured paint: its two-constant Kubelka–Munk absorption [k] and
/// scattering [s] spectra on the canonical grid, plus its identity, [medium],
/// [opacity] (hiding power, derived from S), [provenance] tier and an internal
/// [sourceRef] back to the dataset row it came from (design §4, §10; SI D6/D9).
///
/// A paint belongs to exactly one [medium]. [k] and [s] are each
/// [CanonicalGrid.bins] samples long.
class Pigment {
  const Pigment({
    required this.id,
    required this.name,
    required this.pigmentIndex,
    required this.medium,
    required this.k,
    required this.s,
    required this.opacity,
    required this.provenance,
    required this.sourceRef,
  });

  /// Stable internal identifier (e.g. `golden.titanium_white`).
  final String id;

  /// Human-readable paint name.
  final String name;

  /// Colour Index pigment designation (e.g. `PW6`).
  final String pigmentIndex;

  final Medium medium;

  /// Absorption spectrum K on the canonical grid.
  final Spectrum k;

  /// Scattering spectrum S on the canonical grid.
  final Spectrum s;

  /// Hiding power in 0..1, derived from S.
  final double opacity;

  final Provenance provenance;

  /// Internal reference to the source dataset row/record (design §10, SI D9).
  final String sourceRef;

  @override
  bool operator ==(Object other) =>
      other is Pigment &&
      other.id == id &&
      other.name == name &&
      other.pigmentIndex == pigmentIndex &&
      other.medium == medium &&
      spectraEqual(other.k, k) &&
      spectraEqual(other.s, s) &&
      other.opacity == opacity &&
      other.provenance == provenance &&
      other.sourceRef == sourceRef;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        pigmentIndex,
        medium,
        spectrumHash(k),
        spectrumHash(s),
        opacity,
        provenance,
        sourceRef,
      );
}
