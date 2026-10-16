import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

import 'harness/harness.dart';

/// The acceptance smoke test (never pending): proves the wired shells are
/// reachable end to end through the package's public surface, and that the
/// harness fixtures construct. It asserts only what is true at the shell stage.
///
/// NOTE (updated at FORWARD-2): the forward model is now live, so the former
/// "forward throws UnimplementedError" wiring proof is replaced by the real
/// end-to-end check — forward/reflectanceOf of the synthetic white run through
/// the public surface and return a valid, physically sensible result. (The
/// synthetic white is a flat-spectrum achromatic stand-in, so its predicted
/// colour is a light neutral, not literally white — AC-5/AC-14 cover the
/// mixing/normalization behaviour; this only proves the pipeline is wired.)
void main() {
  group('acceptance harness smoke', () {
    test('both engines construct through the public surface as MixingEngine',
        () {
      expect(customEngine(), isA<MixingEngine>());
      expect(baselineEngine(), isA<MixingEngine>());
    });

    test('pigment tables load through the public loader, medium-tagged on the '
        'canonical grid', () {
      for (final medium in Medium.values) {
        final table = PigmentTable.load(medium);
        expect(table.pigments, isNotEmpty);
        for (final paint in table.pigments) {
          expect(paint.medium, medium);
          expect(paint.k, hasLength(CanonicalGrid.bins));
          expect(paint.s, hasLength(CanonicalGrid.bins));
        }
      }
    });

    test('the forward model is wired and reachable end to end (FORWARD-2)', () {
      // End-to-end wiring proof: forward/reflectanceOf of the synthetic white run
      // through the public surface and return a physically sensible result.
      final whiteMix = <String, double>{synthWhite().id: 1.0};

      final reflectance = customEngine().reflectanceOf(whiteMix);
      expect(reflectance, hasLength(CanonicalGrid.bins));
      expect(reflectance.every((v) => v >= 0.0 && v <= 1.0), isTrue,
          reason: 'measured reflectance must be physical (0..1)');

      final colour = customEngine().forward(whiteMix);
      for (final ch in <double>[colour.srgb.r, colour.srgb.g, colour.srgb.b]) {
        expect(ch, inInclusiveRange(0.0, 1.0));
      }
      // The white pigment is a flat-spectrum achromatic stand-in, so its
      // predicted colour is a light neutral: near-zero chroma and r≈g≈b.
      expect(colour.oklch.c, lessThan(0.02),
          reason: 'a flat-spectrum white must predict a near-neutral colour');
      expect((colour.srgb.r - colour.srgb.g).abs(), lessThan(0.02));
      expect((colour.srgb.g - colour.srgb.b).abs(), lessThan(0.02));
    });

    test('harness fixtures construct', () {
      expect(perfectDiffuser, hasLength(CanonicalGrid.bins));
      expect(perfectDiffuser.every((v) => v == 1.0), isTrue);
      expect(refSpectrumColour.spectrum, hasLength(CanonicalGrid.bins));
      expect(refSpectrumColour.publishedSrgb, (r: 1.0, g: 1.0, b: 1.0));

      // oogColour is genuinely high-chroma (OKLCh C well above a muted mix).
      expect(oogColour.oklch.c, greaterThan(0.2));

      expect(synthPigments(), isNotEmpty);
      expect(synthWhite().id, 'acrylic.titanium_white');

      // Real-data fixtures are explicit placeholders until their gates close.
      expect(acrylicPublishedPlaceholder.isReal, isFalse);
      expect(acrylicPublishedPlaceholder.published, isNull);
      expect(oilMixturesPlaceholder.isReal, isFalse);

      expect(illuminants.isPlaceholder, isTrue);
      expect(illuminants.d65, hasLength(CanonicalGrid.bins));
      expect(illuminants.warm, hasLength(CanonicalGrid.bins));
      // Warm (2856 K) is redder than neutral (6500 K): more long-λ, less short-λ
      // relative power. Checks the two SPDs are genuinely distinct, not copies.
      expect(illuminants.warm.first, lessThan(illuminants.d65.first)); // 400 nm
      expect(illuminants.warm.last, greaterThan(illuminants.d65.last)); // 700 nm
    });
  });
}
