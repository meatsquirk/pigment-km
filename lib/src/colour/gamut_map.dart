import '../types/colour_value.dart';

/// Maps [colour] into the sRGB gamut without hard-clipping (design §2; AC-2).
///
/// A colour predicted outside sRGB (its OKLCh chroma exceeds what sRGB can
/// represent at that lightness and hue) is brought in-gamut by reducing chroma
/// at fixed lightness and hue — a binary search down the OKLCh chroma axis until
/// the encoded sRGB sits inside `[0, 1]` on every channel — never by clipping a
/// channel at 0 or 1. The returned [ColourValue] carries the in-gamut sRGB with
/// its hue and lightness preserved; an already-in-gamut colour is returned
/// unchanged.
///
/// Shell stub (ITEST-2, Option A): the public signature the acceptance suite
/// calls through. **COLOR-3** fills the body; until then this throws the
/// documented [UnimplementedError] so the AC-2 pending test fails on its When
/// for the right reason (the gamut map is not built).
ColourValue gamutMap(ColourValue colour) =>
    throw UnimplementedError('gamutMap — COLOR-3');
