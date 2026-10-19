import 'package:pigment_km/pigment_km.dart';
import 'package:pigment_km/src/tune/chroma_penalty.dart';
import 'package:test/test.dart';

/// Unit tests for the TUNE-2 natural-colour chroma penalty (design §7 lever 2).

/// A recipe carrying a known ΔE00 and a predicted colour of known OKLCh chroma;
/// the other fields are immaterial to the penalty.
Recipe _recipe({required double deltaE00, required double chroma}) => Recipe(
      medium: Medium.acrylic,
      parts: const <String, double>{'p': 1.0},
      colour: ColourValue(
        srgb: (r: 0.5, g: 0.5, b: 0.5),
        xyz: (x: 0.2, y: 0.2, z: 0.2),
        oklch: (l: 0.6, c: chroma, h: 120.0),
      ),
      deltaE00: deltaE00,
      provenance: Provenance.calculated,
      outOfGamut: false,
      verdict: 'test',
    );

void main() {
  group('chromaPenalizedCost', () {
    test('with lambda 0 is exactly the recipe ΔE00 (penalty off)', () {
      final r = _recipe(deltaE00: 3.25, chroma: 0.4);
      expect(chromaPenalizedCost(r, 0.0), 3.25);
    });

    test('with lambda > 0 adds lambda·C* of the predicted colour', () {
      final r = _recipe(deltaE00: 3.0, chroma: 0.2);
      expect(chromaPenalizedCost(r, 0.5), closeTo(3.0 + 0.5 * 0.2, 1e-12));
    });

    test('on a ΔE00 tie the lower-chroma recipe has the lower cost', () {
      final muted = _recipe(deltaE00: 2.0, chroma: 0.1);
      final vivid = _recipe(deltaE00: 2.0, chroma: 0.3);
      final lambda = naturalChromaPenalty;
      expect(chromaPenalizedCost(muted, lambda),
          lessThan(chromaPenalizedCost(vivid, lambda)),
          reason: 'the muted (lower-chroma) recipe must be preferred on a tie');
    });

    test('naturalChromaPenalty is a tiny positive tie-break weight', () {
      // Positive (so it prefers lower chroma) yet so small that its largest
      // nudge (chroma well under 1) is far below a 1 ΔE00 just-noticeable
      // difference — it cannot overturn a visible ΔE00 gap.
      expect(naturalChromaPenalty, greaterThan(0));
      expect(naturalChromaPenalty * 1.0, lessThan(1e-3));
    });
  });
}
