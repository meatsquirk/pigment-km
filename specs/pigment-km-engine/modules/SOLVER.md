# Module SOLVER — the inverse solver

**Status:** Not started
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/engine/inverse.dart` (subset enumeration, per-subset optimizer, ranking, out-of-gamut, medium partition), `lib/src/engine/custom_km_engine.dart` (`inverse`)
**Depends on:** FORWARD · **Blocks:** TUNE, PROD

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 2 (SOLVER-2) | behavior | AC-16 | ⬜ Todo | | |
| 3 (SOLVER-3) | behavior | AC-15 | ⬜ Todo | | |
| 4 (SOLVER-4) | behavior | AC-18 | ⬜ Todo | | |
| 5 (SOLVER-5) | behavior | AC-19 | ⬜ Todo | | |
| 6 (SOLVER-6) | behavior | AC-17 | ⬜ Todo (G-6 evidence) | | |
| 7 (SOLVER-7) | behavior | AC-20 | ⬜ Todo (exclusive lane) | | |

## Interface reconciliation

Design §6.2: enumerate palette subsets by size (prefer fewer paints), per-subset bounded optimization over volumes (simplex `v≥0,Σ=1`, warm-started NNLS in K/S space), match in colour-space ΔE00 (D-6), out-of-gamut returns the nearest flagged (never fabricated), palette partitioned by medium (D-2/§4.3). SOLVER-2 (palette constraint) is the base the rest build on; SOLVER-6/7 (accuracy, perf) come last.

## Open gates
- **G-2** blocks all behavior. **G-6** governs AC-17's validation *evidence* (not the solver logic).

## Phase 2 — SOLVER-2: palette-constrained search (AC-16)

- **Kind:** behavior · **Target AC:** AC-16 (full) · **Depends on:** FORWARD-2 · **Blocks:** SOLVER-3
- **Files:** `inverse.dart`, `custom_km_engine.dart`
- **Tasks:** subset enumeration over the declared palette only; a basic per-subset optimizer; return recipes.
- **Exit criteria:** analyze clean; 100% touched; no paint outside the palette appears.
- **Acceptance gate:** un-pend AC-16; `TestAC16_PaletteOnly` green.

### Result · Checkpoint  <!-- filled on completion -->

## Phase 3 — SOLVER-3: ranking, prefer fewer paints (AC-15)

- **Kind:** behavior · **Target AC:** AC-15 (full) · **Depends on:** SOLVER-2 · **Blocks:** SOLVER-4
- **Files:** `inverse.dart`
- **Tasks:** sort by ΔE00 asc, tie-break fewer paints; top-K; parts Σ1.
- **Exit criteria:** analyze clean; 100% touched; stable order; fewer-paint wins a tie.
- **Acceptance gate:** un-pend AC-15; `TestAC15_RankedFewer` green.

### Result · Checkpoint  <!-- filled on completion -->

## Phase 4 — SOLVER-4: out-of-gamut handling (AC-18)

- **Kind:** behavior · **Target AC:** AC-18 (full) · **Depends on:** SOLVER-3 · **Blocks:** SOLVER-5
- **Files:** `inverse.dart`
- **Tasks:** when best ΔE00 > gamut ceiling, flag `outOfGamut`, keep the true distance, never claim a match (SI fixed intent).
- **Exit criteria:** analyze clean; 100% touched; unreachable target flagged; in-gamut target not flagged (control).
- **Acceptance gate:** un-pend AC-18; `TestAC18_OutOfGamut` green.

### Result · Checkpoint  <!-- filled on completion -->

## Phase 5 — SOLVER-5: cross-medium rule (AC-19)

- **Kind:** behavior · **Target AC:** AC-19 (full) · **Depends on:** SOLVER-4 · **Blocks:** SOLVER-6
- **Files:** `inverse.dart`
- **Tasks:** partition the palette by medium; search each; a recipe is always single-medium (§4.3).
- **Exit criteria:** analyze clean; 100% touched; no recipe spans media even when a cross-medium mix would be closer (control).
- **Acceptance gate:** un-pend AC-19; `TestAC19_CrossMedium` green.

### Result · Checkpoint  <!-- filled on completion -->

## Phase 6 — SOLVER-6: in-gamut accuracy (AC-17)

- **Kind:** behavior · **Target AC:** AC-17 (full) · **Depends on:** SOLVER-5, FORWARD-3 · **Blocks:** SOLVER-7
- **Files:** `inverse.dart` (optimizer quality)
- **Tasks:** tighten the per-subset optimizer so a reachable target solves ≤ 5 ΔE00; record the swatch-set distribution (validation evidence ↔ G-6).
- **Exit criteria:** analyze clean; 100% touched; in-gamut target ≤ 5.
- **Acceptance gate:** un-pend AC-17; `TestAC17_InGamut` green. (Validation confidence noted against G-6.)

### Result · Checkpoint  <!-- filled on completion -->

## Phase 7 — SOLVER-7: performance (AC-20)

- **Kind:** behavior · **Target AC:** AC-20 (full) · **Depends on:** SOLVER-6 · **Blocks:** PROD
- **Files:** `inverse.dart` (perf)
- **Tasks:** ensure top-3 over ~15 paints returns ≤ ~2 s; precompute per-paint weights; cap subset sizes (maxPaints).
- **Exit criteria:** analyze clean; 100% touched; timed run in the **exclusive lane** meets the budget.
- **Acceptance gate:** un-pend AC-20; `TestAC20_Performance` green (exclusive lane).

### Result · Checkpoint  <!-- filled on completion -->
