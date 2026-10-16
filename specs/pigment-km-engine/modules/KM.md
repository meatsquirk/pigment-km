# Module KM — Kubelka–Munk physics

**Status:** Not started
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/km/reflectance.dart` (KM reflectance + inverse f(R)), `lib/src/km/saunderson.dart`, `lib/src/km/mixing.dart` (two-constant Σv·K, Σv·S + concentration)
**Depends on:** CORE · **Blocks:** FORWARD, DATA (ingest round-trip)

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 2 (KM-2) | behavior | AC-3 | ⬜ Todo | | |
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

### Result  <!-- filled on completion -->
### Checkpoint / Handoff  <!-- filled on completion -->

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
