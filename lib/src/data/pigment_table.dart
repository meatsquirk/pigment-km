import 'dart:io';

import '../types/medium.dart';
import '../types/pigment.dart';
import 'artifact_format.dart';

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

  /// The shipped build-artifact path for [medium], relative to the package root
  /// (the directory `dart`/`flutter` runs from). The data ships as a file so the
  /// runtime only *loads* it and never recomputes K,S (design §4, SI D6).
  ///
  /// Until the real licensed datasets land (G-3 acrylic, G-4 oil), the shipped
  /// artifact is the synthetic placeholder (D-7). DATA-5/DATA-6 ingest add the
  /// real `<medium>.json` artifacts and point this at them.
  static String assetPathFor(Medium medium) =>
      'assets/pigments/synthetic_${medium.name}.json';

  /// Decoded tables, memoised per medium. [load] is on the engine's forward
  /// path (every paint-id resolve), so the shipped artifact is read and decoded
  /// once per medium per process, not on every call.
  static final Map<Medium, PigmentTable> _cache = <Medium, PigmentTable>{};

  /// Loads the pigment table for [medium] by decoding its shipped build
  /// artifact ([assetPathFor]) — the file is the single source of truth; nothing
  /// is rebuilt in memory. The decoded artifact is wrapped and memoised.
  ///
  /// Throws [FileSystemException] if the artifact is missing and
  /// [FormatException] (via [PigmentArtifactCodec.decode]) if it is malformed —
  /// a build that ships a bad artifact must fail loudly, never silently.
  static PigmentTable load(Medium medium) =>
      _cache[medium] ??= fromArtifact(
        PigmentArtifactCodec.decode(File(assetPathFor(medium)).readAsStringSync()),
      );

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
