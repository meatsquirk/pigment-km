import 'dart:typed_data';

import 'package:pigment_km/pigment_km.dart';
import 'package:test/test.dart';

Pigment _pigment({
  String id = 'golden.titanium_white',
  double opacity = 0.9,
  Provenance provenance = Provenance.measured,
  List<double> k = const [0, 0.1, 0.2],
  List<double> s = const [1, 0.9, 0.8],
}) =>
    Pigment(
      id: id,
      name: 'Titanium White',
      pigmentIndex: 'PW6',
      medium: Medium.acrylic,
      k: Float32List.fromList(k),
      s: Float32List.fromList(s),
      opacity: opacity,
      provenance: provenance,
      sourceRef: 'golden/row/1',
    );

Recipe _recipe({
  Map<String, double> parts = const {'a': 0.5, 'b': 0.5},
  double deltaE00 = 1.2,
  bool outOfGamut = false,
}) =>
    Recipe(
      medium: Medium.acrylic,
      parts: Map.of(parts),
      colour: const ColourValue(
        srgb: (r: 0.1, g: 0.2, b: 0.3),
        xyz: (x: 0.4, y: 0.5, z: 0.6),
        oklch: (l: 0.7, c: 0.1, h: 120.0),
      ),
      deltaE00: deltaE00,
      provenance: Provenance.calculated,
      outOfGamut: outOfGamut,
      verdict: 'good match',
    );

void main() {
  test('Medium and Provenance expose their documented values', () {
    expect(Medium.values, [Medium.acrylic, Medium.oil]);
    expect(Provenance.values, [
      Provenance.measured,
      Provenance.calculated,
      Provenance.estimated,
      Provenance.confirmed,
    ]);
  });

  group('WetDryTransform', () {
    test('none is the identity transform', () {
      expect(WetDryTransform.none.lightnessDelta, 0);
      expect(WetDryTransform.none.chromaDelta, 0);
      expect(WetDryTransform.none.hueDeltaDeg, 0);
    });

    test('value equality and hashCode', () {
      const a = WetDryTransform(lightnessDelta: -2, chromaDelta: 1, hueDeltaDeg: 3);
      const b = WetDryTransform(lightnessDelta: -2, chromaDelta: 1, hueDeltaDeg: 3);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const WetDryTransform(lightnessDelta: -1)));
      expect(a, isNot(const WetDryTransform(chromaDelta: 9)));
      expect(a, isNot(const WetDryTransform(hueDeltaDeg: 9)));
      expect(a == Object(), isFalse);
    });
  });

  group('MediumConfig', () {
    test('defaults wetDry to the identity transform', () {
      const c = MediumConfig(medium: Medium.oil, k1: 0.04, k2: 0.6);
      expect(c.wetDry, WetDryTransform.none);
    });

    test('value equality and hashCode', () {
      const a = MediumConfig(medium: Medium.acrylic, k1: 0.04, k2: 0.6);
      const b = MediumConfig(medium: Medium.acrylic, k1: 0.04, k2: 0.6);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const MediumConfig(medium: Medium.oil, k1: 0.04, k2: 0.6)));
      expect(a, isNot(const MediumConfig(medium: Medium.acrylic, k1: 0.05, k2: 0.6)));
      expect(a, isNot(const MediumConfig(medium: Medium.acrylic, k1: 0.04, k2: 0.7)));
      expect(
        a,
        isNot(const MediumConfig(
          medium: Medium.acrylic,
          k1: 0.04,
          k2: 0.6,
          wetDry: WetDryTransform(lightnessDelta: -1),
        )),
      );
      expect(a == Object(), isFalse);
    });
  });

  group('ColourValue', () {
    const a = ColourValue(
      srgb: (r: 0.1, g: 0.2, b: 0.3),
      xyz: (x: 0.4, y: 0.5, z: 0.6),
      oklch: (l: 0.7, c: 0.1, h: 120.0),
    );

    test('value equality and hashCode', () {
      const b = ColourValue(
        srgb: (r: 0.1, g: 0.2, b: 0.3),
        xyz: (x: 0.4, y: 0.5, z: 0.6),
        oklch: (l: 0.7, c: 0.1, h: 120.0),
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('differs on any channel set', () {
      expect(
        a,
        isNot(const ColourValue(
          srgb: (r: 0.9, g: 0.2, b: 0.3),
          xyz: (x: 0.4, y: 0.5, z: 0.6),
          oklch: (l: 0.7, c: 0.1, h: 120.0),
        )),
      );
      expect(
        a,
        isNot(const ColourValue(
          srgb: (r: 0.1, g: 0.2, b: 0.3),
          xyz: (x: 0.9, y: 0.5, z: 0.6),
          oklch: (l: 0.7, c: 0.1, h: 120.0),
        )),
      );
      expect(
        a,
        isNot(const ColourValue(
          srgb: (r: 0.1, g: 0.2, b: 0.3),
          xyz: (x: 0.4, y: 0.5, z: 0.6),
          oklch: (l: 0.9, c: 0.1, h: 120.0),
        )),
      );
      expect(a == Object(), isFalse);
    });
  });

  group('Pigment', () {
    test('exposes its fields', () {
      final p = _pigment();
      expect(p.id, 'golden.titanium_white');
      expect(p.name, 'Titanium White');
      expect(p.pigmentIndex, 'PW6');
      expect(p.medium, Medium.acrylic);
      expect(p.k.length, 3);
      expect(p.s.length, 3);
      expect(p.opacity, 0.9);
      expect(p.provenance, Provenance.measured);
      expect(p.sourceRef, 'golden/row/1');
    });

    test('value equality over spectra and hashCode', () {
      expect(_pigment(), equals(_pigment()));
      expect(_pigment().hashCode, _pigment().hashCode);
    });

    test('differs on scalar fields', () {
      final base = _pigment();
      expect(base, isNot(_pigment(id: 'other')));
      expect(base, isNot(_pigment(opacity: 0.1)));
      expect(base, isNot(_pigment(provenance: Provenance.estimated)));
      expect(base == Object(), isFalse);
    });

    test('differs when a spectrum differs', () {
      expect(_pigment(), isNot(_pigment(k: const [9, 9, 9])));
      expect(_pigment(), isNot(_pigment(s: const [9, 9, 9])));
    });
  });

  group('Recipe', () {
    test('exposes its fields', () {
      final r = _recipe();
      expect(r.medium, Medium.acrylic);
      expect(r.parts, {'a': 0.5, 'b': 0.5});
      expect(r.deltaE00, 1.2);
      expect(r.provenance, Provenance.calculated);
      expect(r.outOfGamut, isFalse);
      expect(r.verdict, 'good match');
    });

    test('value equality over parts and hashCode', () {
      expect(_recipe(), equals(_recipe()));
      expect(_recipe().hashCode, _recipe().hashCode);
    });

    test('parts equality is order-independent', () {
      final a = _recipe(parts: const {'a': 0.5, 'b': 0.5});
      final b = _recipe(parts: const {'b': 0.5, 'a': 0.5});
      expect(a, equals(b));
    });

    test('differs on parts length, parts value, and scalar fields', () {
      final base = _recipe();
      expect(base, isNot(_recipe(parts: const {'a': 1.0})));
      expect(base, isNot(_recipe(parts: const {'a': 0.5, 'b': 0.4})));
      expect(base, isNot(_recipe(deltaE00: 9)));
      expect(base, isNot(_recipe(outOfGamut: true)));
      expect(base == Object(), isFalse);
    });
  });

  group('MixOptions', () {
    test('documented defaults', () {
      const o = MixOptions();
      expect(o.maxPaints, 4);
      expect(o.topK, 5);
      expect(o.gamutThreshold, 5.0);
      expect(o.chromaPenalty, isTrue);
      expect(o.wet, isTrue);
    });

    test('value equality and hashCode', () {
      const a = MixOptions(maxPaints: 3, topK: 3);
      const b = MixOptions(maxPaints: 3, topK: 3);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const MixOptions(maxPaints: 2, topK: 3)));
      expect(a, isNot(const MixOptions(maxPaints: 3, topK: 4)));
      expect(a, isNot(const MixOptions(maxPaints: 3, topK: 3, gamutThreshold: 1)));
      expect(a, isNot(const MixOptions(maxPaints: 3, topK: 3, chromaPenalty: false)));
      expect(a, isNot(const MixOptions(maxPaints: 3, topK: 3, wet: false)));
      expect(a == Object(), isFalse);
    });
  });
}
