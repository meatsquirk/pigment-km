import '../grid.dart';
import '../types/colour_value.dart';

/// Converts a reflectance [spectrum] on the [CanonicalGrid] to a [ColourValue]
/// under the D65 illuminant and the CIE 1931 2° standard observer (design §2,
/// §3.5; AC-1).
///
/// The backend weights the spectrum by the precomputed `x̄·D65`, `ȳ·D65`,
/// `z̄·D65` vectors to tristimulus XYZ (normalized so a perfect diffuser yields
/// the D65 white point, Y=1), then encodes XYZ→sRGB and derives OKLCh, returning
/// all three consistent representations.
///
/// Shell stub (ITEST-2, Option A): the public signature the acceptance suite
/// calls through. **COLOR-2** fills the body; until then this throws the
/// documented [UnimplementedError] so the AC-1 pending test fails on its When
/// for the right reason (the colour backend is not built).
ColourValue spectrumToColour(Spectrum spectrum) =>
    throw UnimplementedError('spectrumToColour — COLOR-2');
