import 'dart:convert';
import 'dart:io';

import 'package:pigment_km/pigment_km.dart';
import 'package:pigment_km/src/data/synthetic_fixture.dart';
import 'package:test/test.dart';

/// A valid artifact JSON as a mutable map, taken from the acrylic fixture.
Map<String, dynamic> _baseMap() =>
    jsonDecode(PigmentArtifactCodec.encode(SyntheticFixture.artifact(Medium.acrylic)))
        as Map<String, dynamic>;

/// Decoding [map] (as JSON) is expected to throw a [FormatException].
void _expectFormatError(Map<String, dynamic> map) {
  expect(
    () => PigmentArtifactCodec.decode(jsonEncode(map)),
    throwsFormatException,
  );
}

void main() {
  group('SyntheticFixture', () {
    for (final medium in Medium.values) {
      test('builds a well-formed ${medium.name} table (D-7)', () {
        final artifact = SyntheticFixture.artifact(medium);
        expect(artifact.version, PigmentArtifactCodec.currentVersion);
        expect(artifact.medium, medium);
        expect(artifact.pigments, hasLength(3));
        for (final p in artifact.pigments) {
          expect(p.medium, medium);
          expect(p.k, hasLength(31));
          expect(p.s, hasLength(31));
          expect(p.k.every((v) => v >= 0), isTrue);
          expect(p.s.every((v) => v >= 0), isTrue);
          expect(p.opacity, inInclusiveRange(0, 1));
          // Synthetic data is never presented as measured or calculated.
          expect(p.provenance, Provenance.estimated);
          expect(p.sourceRef, startsWith('synthetic:'));
          expect(p.id, startsWith('${medium.name}.'));
        }
      });
    }
  });

  group('PigmentTable.load', () {
    for (final medium in Medium.values) {
      test('${medium.name} exposes every paint field on the canonical grid', () {
        final table = PigmentTable.load(medium);
        expect(table.medium, medium);
        expect(table.pigments, isNotEmpty);
        for (final p in table.pigments) {
          expect(p.medium, medium);
          expect(p.k, hasLength(31));
          expect(p.s, hasLength(31));
          expect(p.pigmentIndex, isNotEmpty);
          expect(p.sourceRef, isNotEmpty);
        }
      });
    }

    for (final medium in Medium.values) {
      test('${medium.name} is decoded from its shipped artifact — the file is '
          'the single source', () {
        // load == decode(the file at assetPathFor): nothing is rebuilt in
        // memory, so the shipped artifact is authoritative.
        final table = PigmentTable.load(medium);
        final onDisk = File(PigmentTable.assetPathFor(medium)).readAsStringSync();
        final decoded = PigmentArtifactCodec.decode(onDisk);
        expect(table.medium, decoded.medium);
        expect(table.pigments, decoded.pigments);
      });
    }

    test('assetPathFor names the shipped per-medium artifact', () {
      expect(PigmentTable.assetPathFor(Medium.acrylic),
          'assets/pigments/synthetic_acrylic.json');
      expect(PigmentTable.assetPathFor(Medium.oil),
          'assets/pigments/synthetic_oil.json');
    });

    test('a medium is read and decoded once, then memoised (not re-read on the '
        'forward path)', () {
      // The second load returns the identical table — the artifact is decoded
      // once per medium per process, not on every call.
      expect(identical(PigmentTable.load(Medium.acrylic),
          PigmentTable.load(Medium.acrylic)), isTrue);
      expect(identical(PigmentTable.load(Medium.oil),
          PigmentTable.load(Medium.oil)), isTrue);
      // Distinct media get distinct tables.
      expect(identical(PigmentTable.load(Medium.acrylic),
          PigmentTable.load(Medium.oil)), isFalse);
    });

    test('byId finds a paint and returns null for an unknown id', () {
      final table = PigmentTable.load(Medium.acrylic);
      final first = table.pigments.first;
      expect(table.byId(first.id), same(first));
      expect(table.byId('no.such.paint'), isNull);
    });

    test('fromArtifact wraps a decoded artifact', () {
      final artifact = SyntheticFixture.artifact(Medium.oil);
      final table = PigmentTable.fromArtifact(artifact);
      expect(table.medium, Medium.oil);
      expect(table.pigments, hasLength(artifact.pigments.length));
    });
  });

  group('PigmentArtifactCodec round-trip', () {
    for (final medium in Medium.values) {
      test('encode then decode preserves the ${medium.name} table', () {
        final original = SyntheticFixture.artifact(medium);
        final decoded = PigmentArtifactCodec.decode(
          PigmentArtifactCodec.encode(original),
        );
        expect(decoded.version, original.version);
        expect(decoded.medium, original.medium);
        expect(decoded.pigments, original.pigments);
      });
    }
  });

  group('shipped synthetic asset parity (no drift)', () {
    for (final medium in Medium.values) {
      test('assets/pigments/synthetic_${medium.name}.json matches the builder', () {
        final file = File('assets/pigments/synthetic_${medium.name}.json');
        final onDisk = file.readAsStringSync();
        final expected =
            '${PigmentArtifactCodec.encode(SyntheticFixture.artifact(medium))}\n';
        expect(onDisk, expected);
        // And the shipped file decodes back to the same table.
        final decoded = PigmentArtifactCodec.decode(onDisk);
        expect(decoded.pigments, SyntheticFixture.artifact(medium).pigments);
      });
    }
  });

  group('PigmentArtifactCodec.decode rejects malformed artifacts', () {
    test('a non-object root', () {
      expect(() => PigmentArtifactCodec.decode('[]'), throwsFormatException);
    });

    test('an unsupported version', () {
      _expectFormatError(_baseMap()..['version'] = 2);
    });

    test('a non-integer version', () {
      _expectFormatError(_baseMap()..['version'] = 'one');
    });

    test('a non-string medium', () {
      _expectFormatError(_baseMap()..['medium'] = 7);
    });

    test('an unknown medium', () {
      _expectFormatError(_baseMap()..['medium'] = 'gouache');
    });

    test('a missing grid', () {
      _expectFormatError(_baseMap()..['grid'] = 'nope');
    });

    test('a grid not on the canonical grid', () {
      final map = _baseMap();
      (map['grid'] as Map<String, dynamic>)['bins'] = 36;
      _expectFormatError(map);
    });

    test('a non-numeric grid bound', () {
      final map = _baseMap();
      (map['grid'] as Map<String, dynamic>)['start'] = 'low';
      _expectFormatError(map);
    });

    test('a paints value that is not a list', () {
      _expectFormatError(_baseMap()..['paints'] = <String, dynamic>{});
    });

    test('a paint that is not an object', () {
      _expectFormatError(_baseMap()..['paints'] = <Object?>['not a paint']);
    });

    test('a non-string paint field', () {
      final map = _baseMap();
      (map['paints'] as List).first['id'] = 42;
      _expectFormatError(map);
    });

    test('an unknown provenance tier', () {
      final map = _baseMap();
      (map['paints'] as List).first['provenance'] = 'guessed';
      _expectFormatError(map);
    });

    test('a non-numeric opacity', () {
      final map = _baseMap();
      (map['paints'] as List).first['opacity'] = 'high';
      _expectFormatError(map);
    });

    test('a spectrum that is not a list', () {
      final map = _baseMap();
      (map['paints'] as List).first['k'] = 0.5;
      _expectFormatError(map);
    });

    test('a spectrum element that is not a number', () {
      final map = _baseMap();
      ((map['paints'] as List).first['s'] as List)[0] = 'x';
      _expectFormatError(map);
    });

    test('a spectrum of the wrong length', () {
      final map = _baseMap();
      (map['paints'] as List).first['k'] = List<double>.filled(10, 0);
      _expectFormatError(map);
    });
  });
}
