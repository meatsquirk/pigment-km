import '../grid.dart';

/// One tint in a masstone–tint series (design §4.4): the pigment mixed with
/// white at a known [pigmentFraction] (a volume fraction in `(0, 1]`, white
/// making up the remainder `1 - pigmentFraction`), and the [reflectance]
/// measured for that tint on the canonical grid. The masstone is the degenerate
/// tint at `pigmentFraction == 1` (pure pigment, no white).
typedef Tint = ({double pigmentFraction, Spectrum reflectance});

/// Derives a pigment's two-constant Kubelka–Munk absorption [k] and scattering
/// [s] spectra from its [masstone] reflectance and a [tints] series mixed with
/// a white of known [whiteK], [whiteS], by per-wavelength least squares across
/// the series (design §4.4; AC-10).
///
/// The masstone alone fixes only the ratio `K/S` at each wavelength (the opaque
/// reflectance depends on `K/S`, not on `K` and `S` separately); the tint series
/// with a known white separates `K` from `S`, because mixing shifts the
/// volume-weighted `K` and `S` by the pigment fraction. This is the hook for
/// K,S derived from a user's own measured tube.
///
/// Shell stub (ITEST-3, Option A — the standalone surface the AC-10 acceptance
/// test calls through, mirroring the COLOR/KM/ingest stubs ITEST-2 added for
/// AC-1..9). **DATA-4** fills the body; until then this throws the documented
/// [UnimplementedError] so the AC-10 pending test fails on its When for the
/// right reason (the masstone–tint derivation is not built).
({Spectrum k, Spectrum s}) deriveKsFromMasstoneTint({
  required Spectrum masstone,
  required List<Tint> tints,
  required Spectrum whiteK,
  required Spectrum whiteS,
}) =>
    throw UnimplementedError('deriveKsFromMasstoneTint — DATA-4');
