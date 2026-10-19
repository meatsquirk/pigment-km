import 'dart:io';
import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

import 'harness/harness.dart';

/// Acceptance band 1 (ITEST-2): AC-1 … AC-9.
///
/// One pending integration test per AC, driven entirely through the package's
/// public surface. Each test calls [ac] first so it is skipped in the default
/// run and executed under `PIGMENT_KM_RUN_PENDING=true` (the red baseline),
/// where it must fail for the right reason — on a Then, or on a Given
/// precondition naming the owning phase — until that behaviour phase lands.
///
/// The standalone COLOR/KM/DATA backend functions this band calls
/// (`spectrumToColour`, `gamutMap`, `kmReflectance`/`kmFunction`,
/// `saundersonToMeasured`/`configForMedium`, `resampleOntoCanonical`) are the
/// public stubs added in ITEST-2 (Option A); each throws a documented
/// `UnimplementedError` naming its phase until built.
void main() {
  group('COLOR — spectrum → colour backend', () {
    test('AC-1 · TestAC01_SpectrumToColour: a reflectance spectrum converts to '
        'its published colour', () {
      // GIVEN a reflectance spectrum on the canonical 31-bin grid with a known
      // published colour (the perfect diffuser → the D65 white point).
      final ref = refSpectrumColour;
      expect(ref.spectrum, hasLength(CanonicalGrid.bins));
      expect(ref.publishedXyz, (x: 0.94811, y: 1.0, z: 1.07304));
      expect(ref.publishedSrgb, (r: 1.0, g: 1.0, b: 1.0));

      // WHEN the colour backend converts it (D65 illuminant, CIE 1964 10°
      // observer — G-9/D-14).
      final result = spectrumToColour(ref.spectrum);

      // THEN the result matches the published colour within ΔE00 ≤ 1 (the AC
      // threshold), measured by the harness's independent CIEDE2000 reference;
      // Y is normalized to the white point; the sRGB is white.
      expect(deltaE00(result.xyz, ref.publishedXyz), lessThanOrEqualTo(1.0));
      expect(result.xyz.y, closeTo(1.0, 1e-3));
      expect(result.srgb.r, closeTo(1.0, 0.02));
      expect(result.srgb.g, closeTo(1.0, 0.02));
      expect(result.srgb.b, closeTo(1.0, 0.02));
      // Rejects a backend that drops the illuminant weighting or normalizes
      // wrong: it would not land on the D65 white point.
    }, skip: ac('AC-1'));

    test('AC-2 · TestAC02_GamutMap: colours outside sRGB are gamut-mapped, not '
        'clipped', () {
      // GIVEN a predicted colour whose chroma falls outside the sRGB gamut: a
      // vivid green beyond sRGB, so its encoded sRGB has channels outside [0,1].
      const outOfGamut = ColourValue(
        srgb: (r: -0.22, g: 1.09, b: -0.07),
        xyz: (x: 0.28, y: 0.52, z: 0.10),
        oklch: (l: 0.78, c: 0.37, h: 149.0),
      );
      final before = outOfGamut.srgb;
      expect(
        _outsideUnit(before.r) || _outsideUnit(before.g) || _outsideUnit(before.b),
        isTrue,
        reason: 'the Given colour must start outside the sRGB gamut',
      );

      // WHEN the backend maps it into gamut.
      final mapped = gamutMap(outOfGamut);

      // THEN the returned sRGB is inside [0,1] on every channel …
      expect(mapped.srgb.r, inInclusiveRange(0.0, 1.0));
      expect(mapped.srgb.g, inInclusiveRange(0.0, 1.0));
      expect(mapped.srgb.b, inInclusiveRange(0.0, 1.0));
      // … with its hue and lightness preserved and chroma reduced …
      expect(mapped.oklch.l, closeTo(outOfGamut.oklch.l, 0.02),
          reason: 'lightness must be preserved');
      expect(_hueDiffDeg(mapped.oklch.h, outOfGamut.oklch.h), lessThan(2.0),
          reason: 'hue must be preserved');
      expect(mapped.oklch.c, lessThan(outOfGamut.oklch.c),
          reason: 'chroma must be reduced to reach the gamut');
      // … and the reported colour is GENUINELY inside the gamut: its UNCLAMPED
      // linear sRGB (via the independent reference) already lies in [0,1], so no
      // channel is hard-clipped by the encoder. This is the decisive reject: the
      // bare `mapped.srgb ∈ [0,1]` check above is vacuous (the gamma encoder
      // always clamps), so a mapper that stops just above the gamut boundary and
      // leans on that clamp to hide a still-negative channel would otherwise pass
      // while faking the match. The 1e-6 grain is tighter than any boundary
      // excess, so (unlike a tolerance on the clamped sRGB) it leaves no window.
      final reportedLinear = oklchToLinearSrgb(mapped.oklch);
      expect(reportedLinear.r, inInclusiveRange(-1e-6, 1 + 1e-6),
          reason: 'red channel genuinely in gamut — no hidden hard-clip');
      expect(reportedLinear.g, inInclusiveRange(-1e-6, 1 + 1e-6),
          reason: 'green channel genuinely in gamut — no hidden hard-clip');
      expect(reportedLinear.b, inInclusiveRange(-1e-6, 1 + 1e-6),
          reason: 'blue channel genuinely in gamut — no hidden hard-clip');
      // … and the displayable sRGB is consistent with that reported OKLCh (the
      // independent reference re-derives the same hue and lightness from it).
      final refOklch = srgbToOklch(mapped.srgb);
      expect(refOklch.l, closeTo(mapped.oklch.l, 5e-3),
          reason: 'reported lightness matches the sRGB actually returned');
      expect(hueDiffDeg(refOklch.h, mapped.oklch.h), lessThan(0.5),
          reason: 'reported hue matches the sRGB actually returned');
      // … and it is NOT a hard clip of the out-of-range channels (which would
      // pin a channel and shift hue). Rejects the naive per-channel clamp.
      final clamped = (
        r: before.r.clamp(0.0, 1.0),
        g: before.g.clamp(0.0, 1.0),
        b: before.b.clamp(0.0, 1.0),
      );
      expect(
        (mapped.srgb.r - clamped.r).abs() < 1e-6 &&
            (mapped.srgb.g - clamped.g).abs() < 1e-6 &&
            (mapped.srgb.b - clamped.b).abs() < 1e-6,
        isFalse,
        reason: 'gamut mapping must not reduce to a hard per-channel clip',
      );
    }, skip: ac('AC-2'));
  });

  group('KM — Kubelka–Munk physics', () {
    test('AC-3 · TestAC03_KmRoundTrip: Kubelka–Munk reflectance and K/S '
        'round-trip', () {
      // GIVEN a per-wavelength K/S ratio spectrum, finite and > 0.
      final blue = _paint('acrylic.phthalo_blue');
      final koverS = _koverS(blue);
      for (final x in koverS) {
        expect(x.isFinite, isTrue);
        expect(x, greaterThan(0));
      }

      // WHEN reflectance is computed from the K/S ratio …
      final reflectance = kmReflectance(koverS);

      // THEN the reflectance is physical — R∞ ∈ [0, 1] at every wavelength. This
      // is the assertion that REJECTS the branch-sign swap: the correct root
      // R∞ = 1 + x − √(x²+2x) is ≤ 1, while the wrong root 1 + x + √(x²+2x) is
      // > 1. (The round-trip alone cannot catch it: the two roots are
      // reciprocals and the K–M function maps R and 1/R to the same K/S.)
      expect(reflectance, hasLength(CanonicalGrid.bins));
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        expect(reflectance[i], inInclusiveRange(0.0, 1.0),
            reason: 'KM reflectance must be physical (0..1) at bin $i — rejects the +√ branch');
      }
      // AND a known reference point: K/S = 0 (no absorption) → R∞ = 1.
      final rNoAbsorption = kmReflectance(Float32List(CanonicalGrid.bins));
      for (final v in rNoAbsorption) {
        expect(v, closeTo(1.0, 1e-5));
      }

      // AND applying the K–M function to the reflectance recovers the original
      // K/S within floating-point tolerance (the round-trip).
      final recovered = kmFunction(reflectance);
      expect(recovered, hasLength(CanonicalGrid.bins));
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        expect(recovered[i], closeTo(koverS[i], 1e-5),
            reason: 'K/S must round-trip at bin $i');
      }
    }, skip: ac('AC-3'));

    test('AC-4 · TestAC04_Saunderson: Saunderson correction round-trips per '
        'medium', () {
      // GIVEN an internal reflectance and each medium's documented (k1,k2); the
      // two media's constants must differ.
      final internal = Float32List.fromList(
        List<double>.generate(
          CanonicalGrid.bins,
          (i) => 0.2 + 0.6 * i / (CanonicalGrid.bins - 1),
        ),
      );
      final acrylic = configForMedium(Medium.acrylic);
      final oil = configForMedium(Medium.oil);
      expect(acrylic.k1 != oil.k1 || acrylic.k2 != oil.k2, isTrue,
          reason: 'acrylic and oil must carry distinct Saunderson constants');
      // The documented defaults (G-5 confirms the authoritative values); pinned
      // here so the hand-computed forward anchor below is a fixed reference.
      expect(acrylic.k1, closeTo(0.04, 1e-12));
      expect(acrylic.k2, closeTo(0.6, 1e-12));

      // WHEN it is converted to measured reflectance and back (acrylic).
      final measured = saundersonToMeasured(internal, acrylic);
      final roundTripped = saundersonToInternal(measured, acrylic);

      // THEN the recovered internal reflectance equals the original within tol.
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        expect(roundTripped[i], closeTo(internal[i], 1e-5),
            reason: 'internal reflectance must round-trip at bin $i');
      }
      // AND the forward correction is the FULL Saunderson model, not merely an
      // invertible stand-in: measured matches an independent re-derivation of
      // `R_m = k1 + (1−k1)(1−k2)·R_i/(1−k2·R_i)` at every bin, for BOTH media.
      // This pins the k2 internal-reflection term — the round-trip alone cannot
      // (any mutually-inverse pair round-trips), and the per-medium control
      // below cannot (acrylic and oil differ in k1). Rejects a k2-dropping
      // forward such as `R_m = k1 + (1−k1)·R_i` (invertible and per-medium
      // distinct, yet wrong).
      final measuredOil = saundersonToMeasured(internal, oil);
      double refMeasured(double ri, MediumConfig c) =>
          c.k1 + (1 - c.k1) * (1 - c.k2) * ri / (1 - c.k2 * ri);
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        expect(measured[i], closeTo(refMeasured(internal[i], acrylic), 1e-6),
            reason: 'acrylic forward must be the full Saunderson model at bin $i');
        expect(measuredOil[i], closeTo(refMeasured(internal[i], oil), 1e-6),
            reason: 'oil forward must be the full Saunderson model at bin $i');
      }
      // AND a hand-computed fixed anchor (independent of the re-derivation
      // above, so a shared algebra slip can't hide): at bin 0, R_i=0.2 with the
      // documented acrylic (k1=0.04, k2=0.6), R_m = 0.04 + 0.384·0.2/0.88 =
      // 0.12727273.
      expect(internal[0], closeTo(0.2, 1e-6)); // Float32 storage of 0.2
      expect(measured[0], closeTo(0.12727273, 1e-6));
      // AND acrylic and oil use their own distinct k1,k2: the SAME internal
      // input corrects to DIFFERENT measured reflectance per medium (control —
      // rejects a no-op Saunderson, or one global k1,k2 for all media).
      expect(spectraEqual(measured, measuredOil), isFalse,
          reason: 'per-medium constants must make the measured reflectance differ');
      expect(spectraEqual(measured, internal), isFalse,
          reason: 'Saunderson must actually transform the reflectance (not a no-op)');
    }, skip: ac('AC-4'));

    test('AC-5 · TestAC05_TwoConstantMix: two-constant mixing is linear and '
        'order-independent', () {
      final engine = customEngine();
      final white = _paint('acrylic.titanium_white');
      final blue = _paint('acrylic.phthalo_blue');

      // GIVEN two paints and volume fractions summing to 1.
      final mix = <String, double>{white.id: 0.5, blue.id: 0.5};
      expect(mix.values.fold<double>(0, (a, b) => a + b), closeTo(1.0, 1e-12));

      // WHEN the mixture is predicted (K,S formed as volume-weighted sums).
      final pureBlue = engine.forward({blue.id: 1.0});

      // THEN mixing a paint with only itself reproduces that paint's colour at
      // any ratio (the single-paint mix normalizes to the pure paint).
      expect(deltaE00(engine.forward({blue.id: 0.3}).xyz, pureBlue.xyz),
          lessThan(1e-6));
      expect(deltaE00(engine.forward({blue.id: 0.9}).xyz, pureBlue.xyz),
          lessThan(1e-6));

      // AND permuting the order of the components does not change the colour.
      final ab = engine.forward({white.id: 0.5, blue.id: 0.5});
      final ba = engine.forward({blue.id: 0.5, white.id: 0.5});
      expect(deltaE00(ab.xyz, ba.xyz), lessThan(1e-6),
          reason: 'component order must not change the predicted colour');

      // CONTROL 1: a real 2-paint mix differs from each pure paint — rejects a
      // mix that collapses to one component.
      final pureWhite = engine.forward({white.id: 1.0});
      expect(deltaE00(ab.xyz, pureBlue.xyz), greaterThan(1.0));
      expect(deltaE00(ab.xyz, pureWhite.xyz), greaterThan(1.0));

      // CONTROL 2: the mixture depends on the volume ratio — a 25/75 mix differs
      // from both its 75/25 mirror and the 50/50 mix. Rejects an implementation
      // that ignores the volumes (every ratio would give the same colour).
      final q1 = engine.forward({white.id: 0.25, blue.id: 0.75});
      final q3 = engine.forward({white.id: 0.75, blue.id: 0.25});
      expect(deltaE00(q1.xyz, q3.xyz), greaterThan(1.0),
          reason: 'swapping the volume ratio must change the predicted colour');
      expect(deltaE00(q1.xyz, ab.xyz), greaterThan(1e-3),
          reason: 'a 25/75 mix must differ from the 50/50 mix');
    }, skip: ac('AC-5'));
  });

  group('DATA — datasets and ingestion', () {
    test('AC-6 · TestAC06_Artifact: the pigment table ships as a medium-tagged '
        'build artifact', () {
      for (final medium in Medium.values) {
        // GIVEN the shipped pigment-table build artifact, loaded for a medium.
        final table = PigmentTable.load(medium);
        expect(table.pigments, isNotEmpty);

        // THEN every paint exposes K,S on the canonical grid, a pigment index,
        // an opacity in [0,1], a provenance tier, an internal source reference,
        // and is tagged with exactly this one medium.
        for (final p in table.pigments) {
          expect(p.k, hasLength(CanonicalGrid.bins));
          expect(p.s, hasLength(CanonicalGrid.bins));
          expect(p.k.every((v) => v.isFinite), isTrue);
          expect(p.s.every((v) => v.isFinite), isTrue);
          expect(p.pigmentIndex, isNotEmpty);
          expect(p.opacity, inInclusiveRange(0.0, 1.0));
          expect(Provenance.values, contains(p.provenance));
          expect(p.sourceRef, isNotEmpty);
          expect(p.medium, medium);
        }

        // AND the loaded table reflects the shipped artifact file exactly (the
        // "ships as a build artifact" guarantee): load == decode(asset).
        final asset =
            File('assets/pigments/synthetic_${medium.name}.json').readAsStringSync();
        final decoded = PigmentArtifactCodec.decode(asset);
        expect(decoded.medium, medium);
        expect(table.pigments.length, decoded.pigments.length);
        for (var i = 0; i < table.pigments.length; i++) {
          expect(table.pigments[i], decoded.pigments[i],
              reason: 'loaded paint $i must equal the shipped artifact record');
        }
      }
    }, skip: ac('AC-6'));

    test('AC-7 · TestAC07_RoundTripFidelity: every ingested acrylic paint '
        'round-trips to its published colour', () {
      // GIVEN the ingested acrylic (Golden/RIT) pigment table with published
      // colours. PRECONDITION — this is a real-data fidelity check: it needs the
      // licensed Golden/RIT data and its published colours on disk. Until
      // G-3/DATA-5, the acrylicPublished fixture is an explicit placeholder
      // (isReal=false, published=null), so the test fails here naming its owner.
      expect(acrylicPublished.isReal, isTrue,
          reason: 'AC-7 needs the real Golden/RIT acrylic data + published colours — G-3/DATA-5');
      expect(acrylicPublished.published, isNotNull,
          reason: 'AC-7 asserts ΔE00(rendered, published) ≤ 0.5 for every paint — G-3/DATA-5');

      // WHEN each paint's K,S are rendered to its opaque reflectance
      // (kmReflectance) and then to colour (spectrumToColour).
      // THEN the rendered colour reproduces the dataset's published colour for
      // that paint within ΔE00 ≤ 0.5. (DATA-5 augments this from the placeholder
      // to the shipped table; rejects wrong k1,k2 or grid.)
      final published = acrylicPublished.published!;
      for (final p in acrylicPublished.table.pigments) {
        final rendered = spectrumToColour(kmReflectance(_koverS(p)));
        expect(deltaE00(rendered.xyz, published[p.id]!.xyz),
            lessThanOrEqualTo(0.5));
      }
    }, skip: ac('AC-7'));

    test('AC-8 · TestAC08_Resample: native dataset grids are resampled onto the '
        'canonical grid', () {
      // GIVEN a spectrum measured on a native grid (acrylic 380–730 nm @ 10 nm).
      final nativeWavelengths = <double>[
        for (var nm = 380.0; nm <= 730.0 + 1e-9; nm += 10) nm,
      ];
      expect(nativeWavelengths, hasLength(36)); // 380..730 @ 10 nm
      // A known linear ramp value(λ) = (λ − 400) / 300 → 0 at 400, 1 at 700.
      double ramp(double nm) => (nm - 400) / 300;
      final nativeValues = <double>[for (final nm in nativeWavelengths) ramp(nm)];

      // WHEN it is ingested (resampled).
      final out = resampleOntoCanonical(nativeWavelengths, nativeValues);

      // THEN its spectra are on the canonical 400–700 @ 10 grid (length 31), and
      // endpoints + interior interpolate correctly (a linear ramp resamples
      // exactly — this is directly comparable across media on the one grid).
      expect(out, hasLength(CanonicalGrid.bins));
      for (var i = 0; i < CanonicalGrid.bins; i++) {
        final nm = CanonicalGrid.wavelengthAt(i);
        expect(out[i], closeTo(ramp(nm), 1e-5),
            reason: 'resampled value at $nm nm must match the linear ramp');
      }
      expect(out.first, closeTo(0.0, 1e-5)); // 400 nm
      expect(out.last, closeTo(1.0, 1e-5)); // 700 nm
      // Rejects a nearest-bin copy that misplaces wavelengths (copying the
      // native 380 nm sample into the 400 nm slot would give −0.0667, not 0).
    }, skip: ac('AC-8'));

    test('AC-9 · TestAC09_OilFit: oil K and S are fit from mixtures and '
        'validated on held-out ones', () {
      // GIVEN the MPI oil pure-paint + mixture reflectances with published
      // volume ratios and a disjoint train/held-out split. PRECONDITION — a
      // real-data fit: it needs the MPI oil dataset on disk. Until G-4/DATA-6,
      // the oilMixtures fixture is a placeholder (isReal=false, no mixtures), so
      // the test fails here naming its owner.
      expect(oilMixturesPlaceholder.isReal, isTrue,
          reason: 'AC-9 needs the MPI oil pure+mixture reflectances with ratios and a train/held-out split — G-4/DATA-6');

      // WHEN K and S per paint are fit per wavelength by non-negative least
      // squares on the training subset.
      // THEN the fit predicts the held-out mixtures' colours within ΔE00 ≤ 5 and
      // every fit coefficient is non-negative at every wavelength. DATA-6
      // augments this test with the real held-out mixtures and the per-λ
      // coefficient assertions (rejects a fit allowing negative K/S, or one that
      // trains on the held-out set).
    }, skip: ac('AC-9'));
  });
}

/// The synthetic acrylic paint with the given [id] (through the public loader).
Pigment _paint(String id) =>
    synthPigments().firstWhere((p) => p.id == id);

/// A paint's per-wavelength K/S ratio spectrum (both K and S are > 0 on the
/// synthetic fixture, so the ratio is finite and positive).
Spectrum _koverS(Pigment p) {
  final out = Float32List(CanonicalGrid.bins);
  for (var i = 0; i < CanonicalGrid.bins; i++) {
    out[i] = p.k[i] / p.s[i];
  }
  return out;
}

bool _outsideUnit(double v) => v < 0.0 || v > 1.0;

/// The absolute circular hue difference in degrees (0..180).
double _hueDiffDeg(double a, double b) {
  var d = (a - b).abs() % 360;
  if (d > 180) d = 360 - d;
  return d;
}
