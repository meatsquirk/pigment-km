import 'package:test/test.dart';

import 'harness/harness.dart';

/// Guards the pending gate itself (never pending). These assertions are what
/// keeps the per-AC loop in ITEST-2/3/4 from passing vacuously: they pin the
/// map's exact size and keys, and prove every owning phase is a real one.
void main() {
  group('pending gate', () {
    test('lists exactly the 27 acceptance criteria, AC-1..AC-27', () {
      expect(pendingACs, hasLength(27));
      final expected = <String>{for (var i = 1; i <= 27; i++) 'AC-$i'};
      expect(pendingACs.keys.toSet(), expected);
    });

    test('every AC is owned by a real behaviour phase', () {
      expect(pendingACs, hasLength(27)); // self-sufficient: not an empty loop
      for (final entry in pendingACs.entries) {
        expect(
          behaviourPhases,
          contains(entry.value),
          reason: '${entry.key} → "${entry.value}" is not a known build-order '
              'phase',
        );
      }
    });

    test('the 27 owners are the 27 distinct behaviour phases (a bijection)', () {
      // Each behaviour phase delivers exactly one AC, so the owners cover the
      // whole phase set with no duplicate and no stray — a stronger check than
      // membership alone, and it cannot pass if a phase name drifts.
      expect(pendingACs.values.toSet(), behaviourPhases);
      expect(pendingACs.values.toSet(), hasLength(27));
    });
  });
}
