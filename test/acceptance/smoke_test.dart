import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

import 'harness/harness.dart';

/// The acceptance smoke test (never pending): proves the wired shells are
/// reachable end to end through the package's public surface, and that the
/// harness fixtures construct. It asserts only what is true at the shell stage.
///
/// NOTE (drift from the plan task, resolved): the ITEST-1 task names a smoke
/// that "forward of the synthetic white returns a near-white". The forward
/// model is an UnimplementedError stub until the FORWARD phases land, so that
/// assertion cannot hold yet. The available end-to-end wiring proof at the shell
/// stage is: both engines construct through the public barrel, the pigment
/// tables load through the public loader, and forward/reflectanceOf are reachable
/// and throw the *documented* UnimplementedError (not a missing-method error).
/// FORWARD-3 strengthens the forward case below to the near-white assertion
/// (see the ITEST checkpoint).
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

    test('the forward model is wired and reachable (throws the documented '
        'UnimplementedError until FORWARD lands)', () {
      // Shell-stage wiring proof: forward of the synthetic white is reachable
      // through the public surface. FORWARD-3 strengthens this to assert the
      // predicted colour is near-white.
      final whiteMix = <String, double>{synthWhite().id: 1.0};
      expect(
        () => customEngine().forward(whiteMix),
        throwsA(isA<UnimplementedError>()),
      );
      expect(
        () => customEngine().reflectanceOf(whiteMix),
        throwsA(isA<UnimplementedError>()),
      );
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
