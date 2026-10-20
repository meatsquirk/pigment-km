import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

/// TUNE-3 (AC-21) — the curated naturalistic default palette (design §7 lever 1).
void main() {
  group('defaultPalette', () {
    test('acrylic returns the curated earth-forward set, in id order, '
        'single-medium, with full canonical spectra', () {
      final palette = defaultPalette(Medium.acrylic);
      // Exactly the curated ids, in order.
      expect(palette.map((p) => p.id).toList(), curatedAcrylicPaletteIds);
      expect(palette, hasLength(curatedAcrylicPaletteIds.length));
      // Every curated paint is a single-medium acrylic with full K/S spectra on
      // the canonical grid — it is a real, mixable paint record, not a stub.
      for (final p in palette) {
        expect(p.medium, Medium.acrylic);
        expect(p.k, hasLength(CanonicalGrid.bins));
        expect(p.s, hasLength(CanonicalGrid.bins));
      }
    });

    test('is memoised: repeated calls return the identical paint instances '
        '(the real artifact is read once)', () {
      final a = defaultPalette(Medium.acrylic);
      final b = defaultPalette(Medium.acrylic);
      for (var i = 0; i < a.length; i++) {
        expect(identical(a[i], b[i]), isTrue);
      }
    });

    test('oil has no curated default yet (G-4 / DATA-6) and throws, rather than '
        'present a placeholder as curated', () {
      expect(() => defaultPalette(Medium.oil), throwsUnsupportedError);
    });
  });

  group('defaultPaletteById', () {
    test('returns the curated paint for a curated id — the same instance the '
        'palette holds', () {
      final id = curatedAcrylicPaletteIds.first;
      final byId = defaultPaletteById(id);
      expect(byId, isNotNull);
      expect(byId!.id, id);
      expect(identical(byId, defaultPalette(Medium.acrylic).first), isTrue);
    });

    test('returns null for an id that is not a curated default-palette member '
        '(e.g. a vivid paint left out of the limited palette)', () {
      // Phthalo blue is a real Golden/RIT paint but deliberately not in the
      // curated earth palette, so it is not a default-palette member.
      expect(defaultPaletteById('acrylic.phthalo_blue_gs'), isNull);
      expect(defaultPaletteById('acrylic.not_a_paint'), isNull);
    });
  });

  test('the naturalistic chroma ceiling is a muted, positive bound well under '
      'a neon chroma', () {
    // A fixed naturalistic ceiling: muted (below a vivid cadmium ≈0.12–0.17 and
    // a neon target ≈0.30) yet positive. Pins the published constant.
    expect(naturalChromaCeiling, greaterThan(0.0));
    expect(naturalChromaCeiling, lessThan(0.12));
  });
}
