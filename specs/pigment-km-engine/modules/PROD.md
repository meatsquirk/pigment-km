# Module PROD — provenance, baseline engine + A/B, interface freeze

**Status:** Not started
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/engine/provenance.dart` (tier derivation), `lib/src/engine/spectral_baseline_engine.dart` (real single-constant impl), `lib/src/ab/ab_harness.dart`
**Depends on:** SOLVER · **Blocks:** SIGNOFF-1

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 2 (PROD-2) | behavior | AC-24 | ⬜ Todo | | |
| 3 (PROD-3) | behavior | AC-25 | ⬜ Todo | | |

## Interface reconciliation

Design §8 S5: recipes from measured data → `Calculated`; a user-measured tube → `Measured`; a third-party dataset alone never `Measured` (D-8, SI D9). The single-constant `SpectralBaselineEngine` (the Spectral.js-style port) is completed here so the A/B harness (design §8 S0) can run both engines through the frozen `MixingEngine` interface (SI D3) — the interface freezes at this point.

## Open gates
- **G-2** blocks all behavior.

## Phase 2 — PROD-2: provenance tiering (AC-24)

- **Kind:** behavior · **Target AC:** AC-24 (full) · **Depends on:** SOLVER-7, DATA-7 · **Blocks:** —
- **Files:** `provenance.dart`, `custom_km_engine.dart`
- **Tasks:** derive a recipe's tier from its pigments' sources; measured-data → Calculated; user-measured tube → Measured.
- **Exit criteria:** analyze clean; 100% touched; both cases correct; dataset alone never Measured (control).
- **Acceptance gate:** un-pend AC-24; `TestAC24_Provenance` green.

### Result · Checkpoint  <!-- filled on completion -->

## Phase 3 — PROD-3: baseline engine + A/B harness (AC-25)

- **Kind:** behavior · **Target AC:** AC-25 (full) · **Depends on:** SOLVER-7 · **Blocks:** SIGNOFF-1
- **Files:** `spectral_baseline_engine.dart`, `ab/ab_harness.dart`
- **Tasks:** complete the single-constant baseline engine behind `MixingEngine`; A/B harness solving a swatch set with each engine and reporting each one's ΔE00; freeze the interface.
- **Exit criteria:** analyze clean; 100% touched; both engines interchangeable via the interface; harness reports ΔE00 per engine.
- **Acceptance gate:** un-pend AC-25; `TestAC25_ABEngines` green.

### Result · Checkpoint  <!-- filled on completion -->
