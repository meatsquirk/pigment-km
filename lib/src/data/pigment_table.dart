import '../types/medium.dart';
import '../types/pigment.dart';
import 'artifact_format.dart';
import 'synthetic_fixture.dart';

/// A medium's loaded pigment table: every paint available to the engine for one
/// [Medium], read from its shipped build artifact (design §4, SI D6).
///
/// The table is the acceptance read endpoint for the data stage: a loaded table
/// exposes each paint's full record ([Pigment.k]/[Pigment.s] on the canonical
/// grid, [Pigment.pigmentIndex], [Pigment.opacity], [Pigment.provenance],
/// [Pigment.sourceRef]), and every paint is tagged with exactly one [medium].
class PigmentTable {
  PigmentTable._(this.medium, this.pigments);

  final Medium medium;

  /// The paints in this medium's table, in artifact order.
  final List<Pigment> pigments;

  /// Loads the pigment table for [medium].
  ///
  /// Until the real licensed datasets land (G-3 acrylic, G-4 oil), this returns
  /// the synthetic placeholder table (D-7). The behaviour phases swap this to
  /// decode the shipped `assets/pigments/<medium>.json` artifact via
  /// [PigmentArtifactCodec].
  static PigmentTable load(Medium medium) {
    final artifact = SyntheticFixture.artifact(medium);
    return PigmentTable._(artifact.medium, List<Pigment>.unmodifiable(artifact.pigments));
  }

  /// Builds a table directly from a decoded [artifact] (used by ingest and by
  /// tests that decode a shipped artifact).
  static PigmentTable fromArtifact(PigmentArtifact artifact) =>
      PigmentTable._(artifact.medium, List<Pigment>.unmodifiable(artifact.pigments));

  /// The paint with the given [id], or `null` if this table has none.
  Pigment? byId(String id) {
    for (final p in pigments) {
      if (p.id == id) return p;
    }
    return null;
  }
}
