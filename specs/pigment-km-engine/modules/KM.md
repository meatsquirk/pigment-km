# Module KM — Kubelka–Munk physics

**Status:** In progress — KM-2 ✅ done; next KM-3 (AC-4 Saunderson)
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/km/reflectance.dart` (KM reflectance + inverse f(R)), `lib/src/km/saunderson.dart`, `lib/src/km/mixing.dart` (two-constant Σv·K, Σv·S + concentration)
**Depends on:** CORE · **Blocks:** FORWARD, DATA (ingest round-trip)

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 2 (KM-2) | behavior | AC-3 | ✅ Done | 5.87M | 9m 58s (24m) |
| 3 (KM-3) | behavior | AC-4 | ⬜ Todo | | |
| 4 (KM-4) | enabler | — (mixing for AC-5) | ⬜ Todo | | |

## Interface reconciliation

Implements design §3.1 (reflectance + inverse), §3.2 (Saunderson, per-medium k1,k2), §3.3 (two-constant mixing) and §5 (concentration = volume fraction). Opaque/infinite-thickness form (D-5). k1,k2 are per-`MediumConfig`; their authoritative values come from each dataset README (G-5) — until then tests use documented defaults (acrylic ~0.04/~0.6) and assert *structure*, not the literals.

## Open gates

- **G-2** blocks all behavior. **G-5** fixes the authoritative k1,k2 used by DATA's round-trip (not by these property tests).

## Phase 2 — KM-2: reflectance ↔ K/S round-trip (AC-3)

- **Kind:** behavior · **Target AC:** AC-3 (full)
- **Depends on:** CORE-2 · **Blocks:** KM-3
- **Files:** `reflectance.dart`
- **Tasks:** `kmReflectance(KoverS)` = `1 + x − sqrt(x²+2x)`; `kmFunction(R)` = `(1−R)²/(2R)`; elementwise over the grid.
- **Exit criteria:** analyze clean; 100% touched; round-trip within 1e-6 across a sweep of K/S.
- **Acceptance gate:** un-pend AC-3; `TestAC03_KmRoundTrip` green.

### Result

Implemented `kmReflectance` (opaque `R∞ = 1 + x − √(x²+2x)`, the physical −√ root)
and `kmFunction` (`K/S = (1−R)²/(2R)`), both elementwise over the input spectrum
(one output sample per input sample), in `lib/src/km/reflectance.dart`.

- **Gates (all green, first full run — fix passes 0/3):** `dart analyze` clean;
  `dart test` 87 pass / 25 skip / 0 fail; coverage PASS (`reflectance.dart`
  11/11 lines — line-only metric); acceptance default green (9 pass / 25 pending);
  `TestAC03_KmRoundTrip` green under `PIGMENT_KM_RUN_PENDING=true`.
- **Grade gate:** fresh independent adversarial subagent, every un-pended AC test
  (AC-1, AC-3) → **2 A** (no downgrade from Band 1 grid). AC-3's range check in
  `[0,1]` rejects the wrong +√ root (the round-trip alone can't — the two roots
  are reciprocals and f(R)=f(1/R)); 1e-5 round-trip rejects a dropped constant.
- **Un-pend:** deleted AC-3 from `pendingACs` (`pending.dart`), added `AC-3: KM-2`
  to `unpendedACs` (`pending_gate_test.dart`), removed the two KM-2 stub rows from
  `backends_stub_test.dart`.
- **Unit tests:** new `test/km_test.dart` — independent closed-form reference,
  physical range, K/S=0→R=1, x=1→2−√3, strict monotonicity, f(R) known point,
  round-trip across a K/S sweep (0…100) with value-scaled tolerance (Float32
  amplifies round-trip error ~1/(2R²) for strong absorbers).
- **No augmentations** assigned to or newly enabled by this phase.
- Tokens: 5.87M · Time: 9m 58s active (24m 14s wall) — see ledger.

### Checkpoint / Handoff

- **Frozen interface:** `kmReflectance(Spectrum) → Spectrum` and
  `kmFunction(Spectrum) → Spectrum` are exact inverses within fp tolerance over
  `(0,1]` reflectance / `≥0` K/S; elementwise, output length == input length.
  Both exported via the package barrel. KM-3 (`saunderson.dart`) composes with
  these; FORWARD renders `spectrumToColour(kmReflectance(·))` (see AC-7/AC-13).
- **Verification commands (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"`
  first. Analyze `dart analyze`; unit `dart test`; coverage
  `bash tool/coverage_gate.sh <BASE>` (line-only); acceptance default
  `dart test test/acceptance`; run-pending `PIGMENT_KM_RUN_PENDING=true dart test
  test/acceptance`. Un-pend = delete the AC row in `pending.dart` **and** add it
  to `unpendedACs` in `pending_gate_test.dart` **and** drop the stub's
  `throwsUnimplementedError` row(s) in `backends_stub_test.dart`.
- **Next phase KM-3 (AC-4 Saunderson, `saunderson.dart`):** implement
  internal→measured and its inverse taking `(k1,k2)` from `MediumConfig`; prove
  acrylic and oil configs carry distinct constants. `configForMedium`,
  `saundersonToMeasured`, `saundersonToInternal` are still Option-A stubs (their
  KM-3 rows remain in `backends_stub_test.dart`). Authoritative k1,k2 are gated on
  G-5; until then use documented defaults (acrylic ~0.04/~0.6) and assert
  *structure*, not the literals.
- **Known gaps:** none for AC-3.

## Phase 3 — KM-3: Saunderson correction (AC-4)

- **Kind:** behavior · **Target AC:** AC-4 (full)
- **Depends on:** KM-2 · **Blocks:** KM-4, DATA-5
- **Files:** `saunderson.dart`
- **Tasks:** internal→measured and its inverse (design §3.2) taking `(k1,k2)` from `MediumConfig`; prove acrylic and oil configs carry distinct constants.
- **Exit criteria:** analyze clean; 100% touched; round-trip within 1e-6; two media → two results.
- **Acceptance gate:** un-pend AC-4; `TestAC04_Saunderson` green.

### Result  <!-- filled on completion -->
### Checkpoint / Handoff  <!-- filled on completion -->

## Phase 4 — KM-4: two-constant mixing + concentration (enabler — AC-5 un-pends in FORWARD-2)

- **Kind:** enabler · **Target AC:** — (the two-constant-mixing mechanism AC-5 needs; its un-pend moved to **FORWARD-2** per G-2 2026-10-16, because AC-5's colour-level Then runs through `CustomKmEngine.forward`)
- **Depends on:** KM-3 · **Blocks:** FORWARD-2
- **Files:** `mixing.dart`
- **Tasks:** `Kmix=Σv·K`, `Smix=Σv·S` elementwise; concentration = volume fraction (§5); self-mix idempotence; order-independence.
- **Exit criteria:** analyze clean; 100% touched; self-mix==pure colour; permutation invariance (unit-level — AC-5's acceptance gate is in FORWARD-2).

### Result  <!-- filled on completion -->
### Checkpoint / Handoff  <!-- filled on completion -->
