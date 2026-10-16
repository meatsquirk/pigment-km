import 'dart:convert';
import 'dart:typed_data';

import '../grid.dart';
import '../types/medium.dart';
import '../types/pigment.dart';
import '../types/provenance.dart';

/// A decoded pigment-table build artifact for one [medium] (design §4, SI D6).
///
/// The build artifact is the compact, medium-tagged serialization of a medium's
/// pigment table. It is produced offline by ingest (`tool/ingest/`) and only
/// *loaded* at runtime — the runtime never recomputes K,S. All spectra in a
/// decoded artifact are already on the [CanonicalGrid]; media are therefore
/// directly comparable (design §4.3).
class PigmentArtifact {
  const PigmentArtifact({
    required this.version,
    required this.medium,
    required this.pigments,
  });

  /// The schema version the artifact was written with
  /// ([PigmentArtifactCodec.currentVersion]).
  final int version;

  final Medium medium;

  /// Every paint in the medium's table. Each belongs to [medium] and carries
  /// K,S on the canonical grid.
  final List<Pigment> pigments;
}

/// Serializes a [PigmentArtifact] to and from its stored JSON form.
///
/// The on-disk form is a UTF-8 JSON object:
/// ```json
/// {
///   "version": 1,
///   "medium": "acrylic",
///   "grid": { "start": 400, "end": 700, "step": 10, "bins": 31 },
///   "paints": [
///     { "id": "...", "name": "...", "pigmentIndex": "...", "opacity": 0.9,
///       "provenance": "estimated", "sourceRef": "...",
///       "k": [31 numbers], "s": [31 numbers] }
///   ]
/// }
/// ```
/// The embedded `grid` block pins the grid every spectrum is sampled on; a
/// decode rejects any artifact not on the canonical grid, because resampling is
/// an ingest-time step (AC-8), never a load-time one. [encode] writes a stable,
/// indented form so a shipped artifact is diff-reviewable and byte-reproducible.
abstract final class PigmentArtifactCodec {
  /// The schema version [encode] writes and [decode] accepts.
  static const int currentVersion = 1;

  /// Decodes [source] (the stored JSON) into a [PigmentArtifact].
  ///
  /// Throws [FormatException] if [source] is not a JSON object, declares an
  /// unsupported version, names an unknown medium or provenance tier, is not on
  /// the canonical grid, or holds a spectrum of the wrong length.
  static PigmentArtifact decode(String source) {
    final Object? root = jsonDecode(source);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('a pigment artifact must be a JSON object');
    }
    final version = _int(root, 'version');
    if (version != currentVersion) {
      throw FormatException('unsupported pigment artifact version: $version');
    }
    final medium = _medium(_str(root, 'medium'));
    _checkGrid(root['grid']);
    final paintsJson = root['paints'];
    if (paintsJson is! List) {
      throw const FormatException("'paints' must be a JSON list");
    }
    final pigments = <Pigment>[
      for (final paint in paintsJson) _pigment(paint, medium),
    ];
    return PigmentArtifact(
      version: version,
      medium: medium,
      pigments: pigments,
    );
  }

  /// Encodes [artifact] to its stable, indented JSON form.
  static String encode(PigmentArtifact artifact) {
    final map = <String, Object?>{
      'version': artifact.version,
      'medium': artifact.medium.name,
      'grid': <String, Object?>{
        'start': CanonicalGrid.start,
        'end': CanonicalGrid.end,
        'step': CanonicalGrid.step,
        'bins': CanonicalGrid.bins,
      },
      'paints': <Object?>[
        for (final pigment in artifact.pigments) _encodePigment(pigment),
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  static Pigment _pigment(Object? json, Medium medium) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('each paint must be a JSON object');
    }
    return Pigment(
      id: _str(json, 'id'),
      name: _str(json, 'name'),
      pigmentIndex: _str(json, 'pigmentIndex'),
      medium: medium,
      k: _spectrum(json, 'k'),
      s: _spectrum(json, 's'),
      opacity: _double(json, 'opacity'),
      provenance: _provenance(_str(json, 'provenance')),
      sourceRef: _str(json, 'sourceRef'),
    );
  }

  static Map<String, Object?> _encodePigment(Pigment p) => <String, Object?>{
        'id': p.id,
        'name': p.name,
        'pigmentIndex': p.pigmentIndex,
        'opacity': p.opacity,
        'provenance': p.provenance.name,
        'sourceRef': p.sourceRef,
        'k': <double>[for (final v in p.k) v],
        's': <double>[for (final v in p.s) v],
      };

  static void _checkGrid(Object? grid) {
    if (grid is! Map<String, dynamic>) {
      throw const FormatException("'grid' must be a JSON object");
    }
    final bins = _int(grid, 'bins');
    final start = _double(grid, 'start');
    final end = _double(grid, 'end');
    final step = _double(grid, 'step');
    if (bins != CanonicalGrid.bins ||
        start != CanonicalGrid.start ||
        end != CanonicalGrid.end ||
        step != CanonicalGrid.step) {
      throw FormatException(
        'artifact grid $start-$end@$step ($bins bins) is not the '
        'canonical ${CanonicalGrid.start}-${CanonicalGrid.end}'
        '@${CanonicalGrid.step} (${CanonicalGrid.bins} bins); '
        'resample at ingest, not at load',
      );
    }
  }

  static Spectrum _spectrum(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List) {
      throw FormatException("'$key' must be a JSON list of numbers");
    }
    final out = Float32List(value.length);
    for (var i = 0; i < value.length; i++) {
      final n = value[i];
      if (n is! num) {
        throw FormatException("'$key[$i]' must be a number");
      }
      out[i] = n.toDouble();
    }
    if (out.length != CanonicalGrid.bins) {
      throw FormatException(
        "'$key' must have ${CanonicalGrid.bins} samples on the canonical "
        'grid, got ${out.length}',
      );
    }
    return out;
  }

  static Medium _medium(String name) {
    for (final m in Medium.values) {
      if (m.name == name) return m;
    }
    throw FormatException('unknown medium: $name');
  }

  static Provenance _provenance(String name) {
    for (final p in Provenance.values) {
      if (p.name == name) return p;
    }
    throw FormatException('unknown provenance tier: $name');
  }

  static String _str(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw FormatException("'$key' must be a string");
    }
    return value;
  }

  static int _int(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int) {
      throw FormatException("'$key' must be an integer");
    }
    return value;
  }

  static double _double(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num) {
      throw FormatException("'$key' must be a number");
    }
    return value.toDouble();
  }
}
