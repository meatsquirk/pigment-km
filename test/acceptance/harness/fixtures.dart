import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';

/// The acceptance fixtures (design §4.3, §6.2; master-plan test plan).
///
/// Every fixture is test *input* data, built so the per-AC tests (ITEST-2/3/4)
/// share one honest set of paints, spectra and targets. The three real-data
/// fixtures ([acrylicPublishedPlaceholder], [oilMixturesPlaceholder],
/// [illuminants]) are explicit placeholders until their datasets land (G-3
/// acrylic, G-4 oil, G-7 stretch); each carries a flag so the AC tests that
/// depend on them assert a precondition naming the owning gate/phase.

/// `synthPigments` — the hand-authored synthetic acrylic paints (opaque white,
/// phthalo blue, naphthol red) read through the public loader (`PigmentTable`).
/// These are the D-7 placeholder paints, honestly tagged `Provenance.estimated`.
List<Pigment> synthPigments() => PigmentTable.load(Medium.acrylic).pigments;

/// The synthetic opaque white — the first paint in the acrylic table.
Pigment synthWhite() => synthPigments().first;

/// A perfect diffuser: unit reflectance across the whole canonical grid.
final Spectrum perfectDiffuser = CanonicalGrid.checkLength(
  Float32List.fromList(List<double>.filled(CanonicalGrid.bins, 1.0)),
);

/// `refSpectrumColour` (AC-1) — a reference spectrum with its published colour.
typedef RefSpectrum = ({Spectrum spectrum, Xyz publishedXyz, Srgb publishedSrgb});

/// The perfect diffuser is, by definition, the illuminant's white point: under
/// CIE D65 (10° observer — G-9/D-14, normalized Y=1) its XYZ is
/// (0.94811, 1.0, 1.07304) and its sRGB is pure white. A correct COLOR backend
/// must reproduce this (AC-1).
final RefSpectrum refSpectrumColour = (
  spectrum: perfectDiffuser,
  publishedXyz: (x: 0.94811, y: 1.0, z: 1.07304),
  publishedSrgb: (r: 1.0, g: 1.0, b: 1.0),
);

/// `oogColour` (AC-18) — a highly chromatic target no muted synthetic mixture
/// can reach. Pure sRGB green (0,1,0): XYZ via the standard sRGB→XYZ D65 matrix;
/// OKLCh (Ottosson) chroma ≈ 0.295. The synthetic acrylic palette has only a
/// white, a blue and a red (no green primary), so green is genuinely unreachable.
const ColourValue oogColour = ColourValue(
  srgb: (r: 0.0, g: 1.0, b: 0.0),
  xyz: (x: 0.357576, y: 0.715152, z: 0.119192),
  oklch: (l: 0.86644, c: 0.29483, h: 142.495),
);

/// `acrylicPublished` (AC-7, AC-12, AC-21) — the real Golden/RIT paints with
/// their published colours. Placeholder until G-3/DATA-5: [isReal] is false and
/// [published] is null; the acrylic AC tests assert their precondition and run
/// against [synthPigments] (graded *B pending <phase>*) until the data lands.
typedef AcrylicPublished = ({
  PigmentTable table,
  Map<String, ColourValue>? published,
  bool isReal,
});

final AcrylicPublished acrylicPublishedPlaceholder = (
  table: PigmentTable.load(Medium.acrylic),
  published: null,
  isReal: false,
);

/// `oilMixtures` (AC-9) — the MPI pure + mixture reflectances with known ratios
/// and a train/held-out split. Placeholder until G-4/DATA-6: [isReal] is false
/// and no mixtures are present yet; the oil fit AC asserts its precondition.
typedef OilMixtures = ({PigmentTable table, bool isReal});

final OilMixtures oilMixturesPlaceholder = (
  table: PigmentTable.load(Medium.oil),
  isReal: false,
);

/// `measuredMixtures` (AC-12) — measured-paint mixtures at known volume
/// fractions, each with the dataset's published measured colour. Placeholder
/// until G-3/G-4/FORWARD-3: [isReal] is false and [mixtures] is null, so the
/// forward-fidelity AC asserts its precondition (naming FORWARD-3) and the
/// ΔE00 ≤ 5 loop runs once FORWARD-3 populates the real measured mixtures.
typedef MeasuredMixture = ({Map<String, double> parts, ColourValue colour});
typedef MeasuredMixtures = ({
  PigmentTable table,
  List<MeasuredMixture>? mixtures,
  bool isReal,
});

final MeasuredMixtures measuredMixturesPlaceholder = (
  table: PigmentTable.load(Medium.acrylic),
  mixtures: null,
  isReal: false,
);

/// `illuminants` (AC-27, @stretch) — two relative-power SPDs on the canonical
/// grid. Placeholder until STRETCH/G-7: Planckian stand-ins ([warm] ≈ 2856 K,
/// Illuminant-A-like; [d65] ≈ 6500 K daylight CCT), computed from Planck's law
/// and normalized to 1.0 at 560 nm. The exact CIE D65 table and a measured warm
/// studio SPD are finalized when STRETCH is enabled.
typedef Illuminants = ({Spectrum d65, Spectrum warm, bool isPlaceholder});

final Illuminants illuminants = (
  d65: _planckianSpd(6500),
  warm: _planckianSpd(2856),
  isPlaceholder: true,
);

/// Planck's law relative spectral radiance at [cctKelvin], sampled on the
/// canonical grid and normalized to 1.0 at 560 nm.
Spectrum _planckianSpd(double cctKelvin) {
  const h = 6.62607015e-34; // Planck constant (J·s)
  const c = 2.99792458e8; // speed of light (m/s)
  const kB = 1.380649e-23; // Boltzmann constant (J/K)
  double radiance(double nm) {
    final l = nm * 1e-9; // wavelength in metres
    final l5 = math.pow(l, 5).toDouble();
    return 1.0 / (l5 * (math.exp(h * c / (l * kB * cctKelvin)) - 1.0));
  }

  final ref = radiance(560);
  final out = Float32List(CanonicalGrid.bins);
  for (var i = 0; i < CanonicalGrid.bins; i++) {
    out[i] = radiance(CanonicalGrid.wavelengthAt(i)) / ref;
  }
  return out;
}
