import 'dart:math' as math;
import 'dart:typed_data';

import '../grid.dart';
import '../types/medium.dart';
import '../types/pigment.dart';
import '../types/provenance.dart';
import 'artifact_format.dart';

/// The synthetic placeholder pigment tables (design decision D-7).
///
/// A tiny, hand-specified table per medium so the whole engine, the shells and
/// most behaviour can be built and tested *before* the real licensed datasets
/// land (Golden/RIT acrylic — G-3; MPI oil — G-4). The values are plausible but
/// invented, so every synthetic paint is tagged [Provenance.estimated] and its
/// [Pigment.sourceRef] marks it `synthetic:` — nothing here is ever presented as
/// measured or calculated. The real ingest (DATA-5/DATA-6) replaces these tables
/// with the shipped `assets/pigments/<medium>.json` artifacts.
abstract final class SyntheticFixture {
  /// Builds the synthetic [PigmentArtifact] for [medium].
  static PigmentArtifact artifact(Medium medium) {
    switch (medium) {
      case Medium.acrylic:
        return PigmentArtifact(
          version: PigmentArtifactCodec.currentVersion,
          medium: medium,
          pigments: <Pigment>[
            _white(medium, 'titanium_white', 'Titanium White', 'PW6'),
            _chroma(medium, 'phthalo_blue', 'Phthalo Blue', 'PB15',
                peakBin: 4, opacity: 0.55),
            _chroma(medium, 'naphthol_red', 'Naphthol Red', 'PR170',
                peakBin: 22, opacity: 0.6),
          ],
        );
      case Medium.oil:
        return PigmentArtifact(
          version: PigmentArtifactCodec.currentVersion,
          medium: medium,
          pigments: <Pigment>[
            _white(medium, 'lead_white', 'Lead White', 'PW1'),
            _chroma(medium, 'ultramarine', 'Ultramarine Blue', 'PB29',
                peakBin: 6, opacity: 0.4),
            _chroma(medium, 'yellow_ochre', 'Yellow Ochre', 'PY43',
                peakBin: 10, opacity: 0.7),
          ],
        );
    }
  }

  /// A high-scattering, low-absorption white.
  static Pigment _white(Medium medium, String id, String name, String index) {
    final k = Float32List(CanonicalGrid.bins);
    final s = Float32List(CanonicalGrid.bins);
    for (var i = 0; i < CanonicalGrid.bins; i++) {
      k[i] = 0.02;
      s[i] = 0.95;
    }
    return _pigment(medium, id, name, index, k, s, opacity: 0.95);
  }

  /// A chromatic pigment whose absorption K peaks near [peakBin], over a modest,
  /// flat scattering S — a smooth, non-negative stand-in for a real curve.
  static Pigment _chroma(
    Medium medium,
    String id,
    String name,
    String index, {
    required int peakBin,
    required double opacity,
  }) {
    final k = Float32List(CanonicalGrid.bins);
    final s = Float32List(CanonicalGrid.bins);
    for (var i = 0; i < CanonicalGrid.bins; i++) {
      final d = (i - peakBin) / 6.0;
      k[i] = 0.05 + 0.9 * math.exp(-d * d);
      s[i] = 0.3;
    }
    return _pigment(medium, id, name, index, k, s, opacity: opacity);
  }

  static Pigment _pigment(
    Medium medium,
    String id,
    String name,
    String index,
    Spectrum k,
    Spectrum s, {
    required double opacity,
  }) {
    return Pigment(
      id: '${medium.name}.$id',
      name: name,
      pigmentIndex: index,
      medium: medium,
      k: k,
      s: s,
      opacity: opacity,
      provenance: Provenance.estimated,
      sourceRef: 'synthetic:${medium.name}/$id',
    );
  }
}
