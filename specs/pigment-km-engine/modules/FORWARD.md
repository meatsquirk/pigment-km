# Module FORWARD — the forward engine

**Status:** Not started
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/engine/custom_km_engine.dart` (`forward`, `reflectanceOf`), `lib/src/engine/forward.dart`
**Depends on:** COLOR, KM, DATA · **Blocks:** SOLVER, STRETCH

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 2 (FORWARD-2) | behavior | AC-14 | ⬜ Todo | | |
| 3 (FORWARD-3) | behavior | AC-12 | ⬜ Todo (G-3/G-4) | | |
| 4 (FORWARD-4) | behavior | AC-13 | ⬜ Todo | | |

## Interface reconciliation

`forward(mix)` composes KM-4 mixing → KM-2 reflectance → KM-3 Saunderson(medium) → COLOR spectrum→colour (design §6.1). FORWARD-2 (normalization) is the enabler the fidelity and desaturation phases build on, so it comes first.

## Open gates
- **G-2** blocks all behavior. **G-3/G-4** block FORWARD-3's measured-mixture fidelity (synthetic until then).

## Phase 2 — FORWARD-2: normalize + forward pipeline (AC-14, enabler)

- **Kind:** behavior · **Target AC:** AC-14 (full); also makes `forward`/`reflectanceOf` real for later Givens
- **Depends on:** COLOR-3, KM-4, DATA-1 · **Blocks:** FORWARD-3, FORWARD-4, SOLVER-2
- **Files:** `forward.dart`, `custom_km_engine.dart`
- **Tasks:** normalize parts to Σ1; assemble the forward pipeline; implement `reflectanceOf`.
- **Exit criteria:** analyze clean; 100% touched; unnormalized == normalized result.
- **Acceptance gate:** un-pend AC-14; `TestAC14_Normalize` green.

### Result · Checkpoint  <!-- filled on completion -->

## Phase 3 — FORWARD-3: measured-mixture fidelity (AC-12) — needs G-3/G-4

- **Kind:** behavior · **Target AC:** AC-12 (full)
- **Depends on:** FORWARD-2, DATA-5 (acrylic) / DATA-6 (oil) · **Blocks:** —
- **Files:** `custom_km_engine.dart` (tolerance/validation only)
- **Tasks:** validate `forward` against real measured mixtures (Phase-0.5 S2 gate, design §8); record the ΔE00 distribution.
- **Exit criteria:** analyze clean; 100% touched; ΔE00 ≤ 5 on the measured mixtures.
- **Acceptance gate:** un-pend AC-12; `TestAC12_ForwardFidelity` green against real data; **augment** from the synthetic placeholder.

### Result · Checkpoint  <!-- filled on completion -->

## Phase 4 — FORWARD-4: natural desaturation (AC-13)

- **Kind:** behavior · **Target AC:** AC-13 (full)
- **Depends on:** FORWARD-2 · **Blocks:** STRETCH-2
- **Files:** `forward.dart` (no change expected) + test
- **Tasks:** demonstrate chroma(KM mix) < chroma(linear-RGB blend) for two chromatic pigments (the natural-colour property, design §1/§7).
- **Exit criteria:** analyze clean; 100% touched; property holds on synthetic and (post-data) real pigments.
- **Acceptance gate:** un-pend AC-13; `TestAC13_Desaturation` green.

### Result · Checkpoint  <!-- filled on completion -->
