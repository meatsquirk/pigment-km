import 'dart:io';

import '../data/artifact_format.dart';
import '../data/pigment_table.dart';
import '../types/medium.dart';
import '../types/pigment.dart';

/// Design §7 lever 1 — the curated, limited, naturalistic default palette.
///
/// Naturalistic colour is physics plus palette, not an sRGB desaturation filter.
/// The single biggest naturalness lever is the palette the app ships by default:
/// a *curated, limited* set of real earth-forward pigments that physically
/// cannot mix to a neon colour, rather than a full gamut of saturated primaries.
/// Any mixture of a curated default palette renders at or below the naturalistic
/// chroma ceiling ([naturalChromaCeiling]); a vivid primary (a cadmium, a neon
/// target) lies above it. This is what AC-21 proves.
///
/// The curated acrylic palette draws its paints from the shipped **real**
/// Golden/RIT acrylic table (DATA-5, `assets/pigments/acrylic.json`) — not the
/// synthetic solver placeholder (`PigmentTable.load(Medium.acrylic)`), which is
/// the controlled three-paint set the in-gamut solver ACs depend on and which
/// TUNE-3 deliberately leaves untouched.

/// The naturalistic chroma ceiling, in OKLCh chroma (C).
///
/// A fixed property of *naturalistic* colour, not of any one palette: every
/// mixture of a curated default palette must render at or below it, while a
/// saturated primary (e.g. a cadmium at C≈0.12–0.17, or a pure-neon target at
/// C≈0.30 through this engine's measured-data pipeline) lies above it. The
/// curated earth palette's most saturated mixture sits at C≈0.078, comfortably
/// under this ceiling; a palette that admitted a vivid primary would breach it.
const double naturalChromaCeiling = 0.10;

/// The curated Zorn-style earth-forward acrylic default palette (design §7
/// lever 1): a warm buff white, the yellow and red earths, the browns and a
/// black — a limited naturalistic set whose every mixture stays muted (OKLCh
/// C ≤ [naturalChromaCeiling]) while still reaching the earths, greys and the
/// skin/landscape tones real painters build from these pigments. Each id selects
/// a paint from the shipped real Golden/RIT acrylic table (DATA-5).
const List<String> curatedAcrylicPaletteIds = <String>[
  'acrylic.titan_buff', // warm semi-opaque off-white (the palette's lightener)
  'acrylic.yellow_ochre', // earth yellow
  'acrylic.red_oxide', // earth red
  'acrylic.burnt_sienna', // warm red-brown earth
  'acrylic.burnt_umber', // warm dark brown earth
  'acrylic.raw_umber', // cool dark brown earth
  'acrylic.mars_black', // neutral black
];

/// The shipped real acrylic artifact (DATA-5). The curated palette and its
/// id resolver read this measured table, read-and-decoded once per process.
const String _realAcrylicAssetPath = 'assets/pigments/acrylic.json';

/// The curated acrylic paints by id, decoded from the real artifact and filtered
/// to [curatedAcrylicPaletteIds] once. [defaultPaletteById] is on the engine's
/// paint-id resolve path, so the artifact is read a single time, not per call.
Map<String, Pigment>? _curatedAcrylicById;

Map<String, Pigment> _loadCuratedAcrylic() {
  final table = PigmentTable.fromArtifact(
    PigmentArtifactCodec.decode(
      File(_realAcrylicAssetPath).readAsStringSync(),
    ),
  );
  final byId = <String, Pigment>{for (final p in table.pigments) p.id: p};
  return <String, Pigment>{
    for (final id in curatedAcrylicPaletteIds) id: byId[id]!,
  };
}

/// The curated naturalistic default palette for [medium] (design §7 lever 1),
/// in [curatedAcrylicPaletteIds] order.
///
/// Acrylic returns the Zorn-style earth-forward set drawn from the shipped real
/// acrylic table. Oil has no curated default yet — the measured oil dataset is
/// pending (G-4 / DATA-6) — so it throws [UnsupportedError] rather than present
/// a synthetic placeholder as if it were curated.
List<Pigment> defaultPalette(Medium medium) {
  switch (medium) {
    case Medium.acrylic:
      return (_curatedAcrylicById ??= _loadCuratedAcrylic()).values.toList();
    case Medium.oil:
      throw UnsupportedError(
        'no curated oil default palette yet — the measured oil dataset is '
        'pending (G-4 / DATA-6)',
      );
  }
}

/// The curated default-palette paint with [id], or `null` if [id] is not a
/// member of any curated default palette.
///
/// The engines' id resolver ([CustomKmEngine]/[SpectralBaselineEngine]) falls
/// back to this after the shipped medium tables, so a mixture of the shipped
/// default palette — real paints that are *not* in the synthetic solver tables —
/// can be predicted through the public `forward`.
Pigment? defaultPaletteById(String id) =>
    (_curatedAcrylicById ??= _loadCuratedAcrylic())[id];
