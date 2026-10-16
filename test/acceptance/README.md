# Acceptance suite — convention

The acceptance (integration) tests for the pigment_km engine live here, one test
per Acceptance Criterion (AC) of `specs/pigment-km-engine.feature`. The harness,
fixtures and per-AC tests are built by the `ITEST` phases; this file fixes the
conventions the scaffold establishes so every later phase agrees.

## Layout

```
test/acceptance/
  README.md            # this file
  harness/             # fake/loopback fixtures, builders, shared setup  (ITEST-1)
  <ac-group>_test.dart # the per-AC acceptance tests                     (ITEST-2..4)
```

## Running

Default mode (the committed state — every *pending* AC test is skipped so the
suite stays green while behaviour is still unbuilt):

```sh
dart test test/acceptance
```

Red-baseline mode (un-skips the pending tests to prove they fail before their
behaviour exists — used to record each AC-test phase's red baseline):

```sh
PIGMENT_KM_RUN_PENDING=true dart test test/acceptance
```

## The pending convention

A not-yet-implemented AC test reads the environment flag and skips unless it is
set, e.g.:

```dart
const runPending = bool.fromEnvironment('PIGMENT_KM_RUN_PENDING');
// or, when invoked via the shell variable:
final runPending = Platform.environment['PIGMENT_KM_RUN_PENDING'] == 'true';

test('AC-N …', () { … }, skip: runPending ? false : 'pending: behaviour not built');
```

The exact helper is provided by the harness in `harness/`. Behaviour phases
un-skip their AC test (remove the `skip:`) as they land the code.
