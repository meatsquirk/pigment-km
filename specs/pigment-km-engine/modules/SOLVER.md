# Module SOLVER — the inverse solver

**Status:** In progress — SOLVER-2 ✅ (palette-constrained search live; AC-16 ✅); next SOLVER-3
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/engine/inverse.dart` (subset enumeration, per-subset optimizer, ranking, out-of-gamut, medium partition), `lib/src/engine/custom_km_engine.dart` (`inverse`)
**Depends on:** FORWARD · **Blocks:** TUNE, PROD

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 2 (SOLVER-2) | behavior | AC-16 | ✅ Done | 9.98M | 17m 22s (1h 13m) |
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

### Result · Checkpoint

**Result (SOLVER-2 · AC-16).** New `lib/src/engine/inverse.dart`:
`solvePaletteConstrained(target, palette, opts)` builds candidates by enumerating
palette subsets (size 1…`maxPaints`, capped at palette length) and fitting each
subset's volume fractions on a simplex grid (`_gridSteps=12`, every paint in a
k-subset carries a strictly-positive share so pure/edge mixes come from the
smaller subsets) minimizing a new library CIEDE2000; returns recipes ordered
best-first by ΔE00, truncated to `topK`. Because only palette paints are ever
considered — the resolver is built from the palette list — no paint outside it can
appear (AC-16). `CustomKmEngine.inverse` now delegates here (was
`UnimplementedError`). Added library ΔE00 `deltaE2000Lab`/`deltaE2000Xyz`
(XYZ→CIELAB/D65→Sharma–Wu–Dalal), exported from the barrel (the solver fn is NOT
exported, so acceptance tests reach it only via the engine). Recipe provenance =
weakest input tier (any `estimated` → estimated, else `calculated`; PROD-2
refines measured-vs-calculated). **Deliberate placeholders for later phases:**
`outOfGamut` hardcoded `false` (SOLVER-4 sets the honest flag); ΔE ordering has no
prefer-fewer tie-break (SOLVER-3); no explicit cross-medium partition (SOLVER-5 —
SOLVER-2 assumes a single-medium palette, which AC-16 satisfies); basic grid
optimizer (SOLVER-6 tightens to ≤5 ΔE00); no perf cap (SOLVER-7).
- **Verification:** `dart analyze` → No issues · unit+acceptance `dart test` →
  **126 passed / 20 skipped / 0 failed** (new `test/engine_test.dart` solver +
  ΔE2000-branch cases; `engine_test` inverse-stub assertion updated to the live
  solver) · acceptance default `dart test test/acceptance` → **14 passed / 20
  skipped** (AC-16 skip→pass; was 13/21) · AC-16 under
  `PIGMENT_KM_RUN_PENDING=true` green · coverage gate (vs BASE `1413680`) → **PASS**
  (`inverse.dart` 109/109, `custom_km_engine.dart` 11/11; `pigment_km.dart` no
  executable lines). Coverage is line-only (CORE metric deviation); every ΔE2000
  hue/chroma arm and f() regime exercised by targeted unit tests.
- **Grade gate:** fresh independent adversarial subagent, G1–G6, given all prior
  grids → **7 A** (AC-16 A newly-live; AC-1/2/3/4/5/14 re-confirmed A — SOLVER-2
  touched no shared helper). Grid section "Behaviour re-grade — SOLVER-2 …"
  appended. No augmentation owed. Fix passes: 0/3.
- **Augmentations:** none. (SOLVER-3/4 will augment the ranking/out-of-gamut ACs.)
- **Tokens / time:** 9.98M · 17m 22s active (1h 13m wall) — 1 session.

**Checkpoint / Handoff.**
- **Frozen interface:** `CustomKmEngine.inverse` → `solvePaletteConstrained`
  (`lib/src/engine/inverse.dart`); public `deltaE2000Lab`/`deltaE2000Xyz` are the
  library's ΔE00 (use these, not the test harness's reference, in lib code).
- **Verification commands (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"`
  first. Analyze `dart analyze`; unit+acceptance `dart test`; coverage
  `bash tool/coverage_gate.sh <BASE>`; acceptance default `dart test test/acceptance`,
  red-baseline `PIGMENT_KM_RUN_PENDING=true dart test test/acceptance -x stretch`.
  Un-pend = delete the AC row in `pending.dart` **and** add it to `unpendedACs` in
  `pending_gate_test.dart` (inverse has no `backends_stub_test` row).
- **For SOLVER-3 (AC-15, ranking/prefer-fewer):** ordering by ΔE00 already exists;
  add the fewer-paint tie-break (sort key `(deltaE00, parts.length)`) and the
  guaranteed-tie augmentation on `TestAC15_RankedPreferFewer`. Only `inverse.dart`.
  Known gap to close later: `outOfGamut` is still a `false` placeholder until
  SOLVER-4; a single-medium palette is assumed until SOLVER-5.

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
