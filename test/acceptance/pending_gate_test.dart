import 'package:test/test.dart';

import 'harness/harness.dart';

/// The ACs whose behaviour has landed, so their row has been **deleted** from
/// [pendingACs] (un-pend = delete the row — ITEST-1 contract). Each behaviour
/// phase adds its AC here in the same change that deletes the row, which keeps
/// the guards below pinning the whole set of 27 even as the map shrinks (so the
/// per-AC loop in ITEST-2/3/4 still cannot pass vacuously). Maps the un-pended
/// AC to the phase that delivered it, mirroring [pendingACs]'s AC→phase shape.
const Map<String, String> unpendedACs = <String, String>{
  'AC-1': 'COLOR-2',
  'AC-2': 'COLOR-3',
  'AC-3': 'KM-2',
  'AC-4': 'KM-3',
  'AC-5': 'KM-4',
  'AC-14': 'FORWARD-2',
  'AC-15': 'SOLVER-3',
  'AC-16': 'SOLVER-2',
};

/// Guards the pending gate itself (never pending). The assertions pin the full
/// AC set (pending ⊎ un-pended = AC-1..AC-27) and the phase bijection, so they
/// stay honest as behaviour phases move ACs from [pendingACs] to [unpendedACs].
void main() {
  group('pending gate', () {
    final allACs = <String>{for (var i = 1; i <= 27; i++) 'AC-$i'};

    test('pending and un-pended together are exactly the 27 criteria, '
        'AC-1..AC-27, and disjoint', () {
      final pending = pendingACs.keys.toSet();
      final unpended = unpendedACs.keys.toSet();
      expect(pending.intersection(unpended), isEmpty,
          reason: 'an AC is either pending or un-pended, never both');
      expect(pending.union(unpended), allACs);
      // Exact sizes, so neither set can silently drift (anti-vacuous).
      expect(pendingACs, hasLength(27 - unpendedACs.length));
      expect(pendingACs.keys.toSet(), allACs.difference(unpended));
    });

    test('every pending AC is owned by a distinct real behaviour phase', () {
      expect(pendingACs, isNotEmpty); // self-sufficient: not an empty loop
      for (final entry in pendingACs.entries) {
        expect(
          behaviourPhases,
          contains(entry.value),
          reason: '${entry.key} → "${entry.value}" is not a known build-order '
              'phase',
        );
      }
      // Each behaviour phase delivers exactly one AC: owners never repeat.
      expect(pendingACs.values.toSet(), hasLength(pendingACs.length));
    });

    test('the 27 owners across pending and un-pended are the 27 distinct '
        'behaviour phases (a bijection)', () {
      // Each un-pended AC's delivering phase is also a real, distinct one; the
      // full owner set covers every behaviour phase with no duplicate and no
      // stray — it cannot pass if a phase name drifts on either side.
      for (final entry in unpendedACs.entries) {
        expect(behaviourPhases, contains(entry.value),
            reason: '${entry.key} → "${entry.value}" is not a known phase');
      }
      final allOwners = <String>{...pendingACs.values, ...unpendedACs.values};
      expect(allOwners, behaviourPhases);
      expect(allOwners, hasLength(27));
    });
  });
}
