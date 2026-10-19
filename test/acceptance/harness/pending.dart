import 'dart:io';

/// The pending gate for the acceptance suite (design §8 staged build).
///
/// [pendingACs] maps every not-yet-built Acceptance Criterion to the behaviour
/// phase that will implement it (the build order in MASTER_PLAN_FOR_FEATURE.md).
/// An AC listed here is *pending*: its acceptance test is skipped in the default
/// run and executed only under `PIGMENT_KM_RUN_PENDING=true`, so the suite stays
/// green while behaviour is still unbuilt while the run-pending mode still proves
/// each test fails for the right reason (the red baseline). A behaviour phase
/// un-pends its AC by deleting that AC's row here.
///
/// ITEST-1 seeds all 27 ACs as pending; ITEST-2/3/4 add one test per AC.
const Map<String, String> pendingACs = <String, String>{
  'AC-9': 'DATA-6',
  'AC-11': 'DATA-7',
  'AC-12': 'FORWARD-3',
  'AC-21': 'TUNE-3',
  'AC-26': 'STRETCH-2',
  'AC-27': 'STRETCH-3',
};

/// The closed set of behaviour phase names the build order defines — the only
/// phases a pending AC may be owned by. Keeping it here lets the pending gate be
/// checked for "every AC names a real phase" without reading the plan, so the
/// gate test cannot pass vacuously.
const Set<String> behaviourPhases = <String>{
  'COLOR-2', 'COLOR-3',
  'KM-2', 'KM-3', 'KM-4',
  'FORWARD-2', 'FORWARD-3', 'FORWARD-4',
  'DATA-2', 'DATA-3', 'DATA-4', 'DATA-5', 'DATA-6', 'DATA-7',
  'SOLVER-2', 'SOLVER-3', 'SOLVER-4', 'SOLVER-5', 'SOLVER-6', 'SOLVER-7',
  'TUNE-2', 'TUNE-3', 'TUNE-4',
  'PROD-2', 'PROD-3',
  'STRETCH-2', 'STRETCH-3',
};

/// True when the run-pending mode is active (the red-baseline run). Read from
/// the process environment because the mode is selected with a shell variable
/// (`PIGMENT_KM_RUN_PENDING=true dart test test/acceptance`).
final bool runPending = Platform.environment['PIGMENT_KM_RUN_PENDING'] == 'true';

/// The pending-gate decision for an AC's acceptance test, passed to the
/// `skip:` argument of `test(...)`:
///
/// ```dart
/// test('AC-1: …', () { /* body */ }, skip: ac('AC-1'));
/// ```
///
/// Returns a skip-reason string when [acId] is still pending and the run-pending
/// mode is off — so package:test skips the test entirely and its body never runs
/// (the default suite stays green). Returns `null` when the AC is un-pended, or
/// under `PIGMENT_KM_RUN_PENDING=true`, so the test runs and must pass (behaviour
/// built) or fail on its Then/precondition — the red baseline.
///
/// (It must be the `skip:` argument, not a call inside the body: a body-level
/// `markTestSkipped` records a skip but does **not** stop the body executing, so
/// a pending test would still run its unbuilt When and error.)
String? ac(String acId) {
  final owner = pendingACs[acId];
  if (owner != null && !runPending) {
    return '$acId pending: behaviour not built yet (owner: $owner)';
  }
  return null;
}
