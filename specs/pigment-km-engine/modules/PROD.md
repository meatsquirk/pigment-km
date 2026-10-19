# Module PROD — provenance, baseline engine + A/B, interface freeze

**Status:** ✅ Done (PROD-2 ✅; PROD-3 ✅) — module complete
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/engine/provenance.dart` (tier derivation), `lib/src/engine/spectral_baseline_engine.dart` (real single-constant impl), `lib/src/ab/ab_harness.dart`
**Depends on:** SOLVER · **Blocks:** SIGNOFF-1

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 2 (PROD-2) | behavior | AC-24 | ✅ Done | 7.07M | 12m 45s |
| 3 (PROD-3) | behavior | AC-25 | ✅ Done | 11.30M | 18m 43s |

## Interface reconciliation

Design §8 S5: recipes from measured data → `Calculated`; a user-measured tube → `Measured`; a third-party dataset alone never `Measured` (D-8, SI D9). The single-constant `SpectralBaselineEngine` (the Spectral.js-style port) is completed here so the A/B harness (design §8 S0) can run both engines through the frozen `MixingEngine` interface (SI D3) — the interface freezes at this point.

## Open gates
- **G-2** blocks all behavior.

## Phase 2 — PROD-2: provenance tiering (AC-24)

- **Kind:** behavior · **Target AC:** AC-24 (full) · **Depends on:** SOLVER-7 · **Blocks:** —
  - *Dependency reconciled (PROD-2, 2026-10-19):* the earlier `DATA-7` dependency was spurious drift. The master dependency graph has `SOLVER-7 --> PROD-2` only, with DATA-7 a separate SIGNOFF-1 leaf; and AC-24 is pure tiering logic — `TestAC24_Provenance` builds its calculated/measured pigments by re-tagging `synthPigments()` (`_retag`), so it never needs the real G-3 dataset DATA-7 brings. PROD-2 was startable with SOLVER-7 done.
- **Files:** `provenance.dart`, `custom_km_engine.dart`
- **Tasks:** derive a recipe's tier from its pigments' sources; measured-data → Calculated; user-measured tube → Measured.
- **Exit criteria:** analyze clean; 100% touched; both cases correct; dataset alone never Measured (control).
- **Acceptance gate:** un-pend AC-24; `TestAC24_Provenance` green.

### Result · Checkpoint

**PROD-2 ✅ (2026-10-19): AC-24 provenance tiering un-pended, green.** A recipe's honesty tier is now derived as *no stronger than its weakest input*. New `lib/src/engine/provenance.dart` — `recipeProvenance(Iterable<Pigment>)` returns the weakest pigment tier by the source-honesty order `estimated(0) < calculated(1) < measured(2) < confirmed(3)` (private `_sourceStrength`); empty → `estimated`. `inverse.dart`: the old private `_recipeProvenance` (`any estimated ? estimated : calculated`) is deleted and its single call site now calls `recipeProvenance(subset)` (import swapped `types/provenance.dart` → `engine/provenance.dart`). So a recipe from the shipped measured dataset (paints tagged `calculated`) is **Calculated**, a recipe from only the user's own measured tube is **Measured**, and the moment a recipe leans on a dataset paint it drops to Calculated (D-8 / SI D9). `custom_km_engine.dart` is unchanged — it delegates to the solver, which is the single Recipe-construction site.

- **File-list reconciliation:** the plan listed `provenance.dart, custom_km_engine.dart`. The derivation's single home is where the `Recipe` is built — `inverse.dart` (`_bestRecipeForSubset`) — so the touched files are `provenance.dart` (new) + `inverse.dart`; `custom_km_engine.dart` needs no change.
- **Dependency reconciliation:** the plan's `DATA-7` dependency was spurious drift (see the Phase 2 note) — AC-24 is pure tiering logic over re-tagged `synthPigments()`, needing only SOLVER-7.
- **Verification** (BASE `001ab07`; `export PATH="$HOME/development/flutter/bin:$PATH"` first). `dart analyze` → clean on touched files (the one pre-existing `info` is TUNE-2's test file, untouched). `dart test` → **192 passed / 8 skipped**; `dart test test/acceptance -x stretch` → **28 passed / 6 skipped** (AC-24 live, un-skipped); `PIGMENT_KM_RUN_PENDING=true dart test test/acceptance -x stretch -N "AC-24"` → green (red-baseline flips). Coverage gate → **PASS** (`inverse.dart` 146/146, `provenance.dart` 9/9). New unit test `test/provenance_test.dart` (6 tests) pins every tier branch (empty→estimated, all-calculated, all-measured, measured+calculated→calculated both orders, estimated drags down, confirmed never weakens).
- **Augmentations:** pending-gate bijection — moved AC-24 from `pendingACs` (`pending.dart`) to `unpendedACs` (`pending_gate_test.dart`) in the same change.
- **Grade gate:** fresh independent adversarial grader — **19 A, 0 B, 0 downgrades, 0 fixes** (AC-24 A + 18 carried re-confirmed). AC-24 discriminates all three named wrong impls (verified by mutation: always-calculated fails the tube case, always-measured fails the dataset case). No regression: AC-24 is the only acceptance test reading `recipe.provenance`, and `synthPigments()` are all `estimated` so old and new rules agree on every carried path.
- **Fix passes:** 0/3 (first full run green across analyze, unit+coverage, acceptance, grade).

**Checkpoint / Handoff.**
- **Frozen interface:** `recipeProvenance(Iterable<Pigment>) → Provenance` in `lib/src/engine/provenance.dart` (engine-internal, not barrel-exported — read through `Recipe.provenance`, mirroring `chroma_penalty.dart`). Weakest-input rule, order estimated<calculated<measured<confirmed.
- **Known gaps:** none for AC-24. `confirmed` is handled in the rule for completeness but no pigment source currently produces it (no behaviour depends on that path beyond the unit test).
- **Next phase (PROD-3, AC-25):** complete the single-constant `SpectralBaselineEngine` behind `MixingEngine` + the A/B harness (`ab/ab_harness.dart`); freeze the interface. Depends on SOLVER-7 (done). Touches `lib/src/engine/*` — merge-risky with any engine phase; no other engine phase is currently in flight.
- **Verification commands (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"` first. `dart analyze`; `dart test`; coverage `bash tool/coverage_gate.sh <BASE>`; acceptance default `dart test test/acceptance -x stretch`; run-pending `PIGMENT_KM_RUN_PENDING=true dart test test/acceptance -x stretch`.

## Phase 3 — PROD-3: baseline engine + A/B harness (AC-25)

- **Kind:** behavior · **Target AC:** AC-25 (full) · **Depends on:** SOLVER-7 · **Blocks:** SIGNOFF-1
- **Files:** `spectral_baseline_engine.dart`, `ab/ab_harness.dart`
- **Tasks:** complete the single-constant baseline engine behind `MixingEngine`; A/B harness solving a swatch set with each engine and reporting each one's ΔE00; freeze the interface.
- **Exit criteria:** analyze clean; 100% touched; both engines interchangeable via the interface; harness reports ΔE00 per engine.
- **Acceptance gate:** un-pend AC-25; `TestAC25_ABEngines` green.

### Result · Checkpoint

**PROD-3 ✅ (2026-10-19): AC-25 A/B interchangeable engines un-pended, green. The `MixingEngine` interface is now frozen.** The single-constant spectral baseline engine is complete and the A/B harness ships, so both engines drive through the identical `MixingEngine.inverse(target, palette, opts)` call with no caller change (AC-25, SI D3). 20 A re-grade (AC-25 A + 19 carried re-confirmed), 0 downgrades, 0 fixes.

- **What landed.** `lib/src/engine/spectral_baseline_engine.dart` filled in from its shell: a genuine **single-constant** model — each paint is reduced to its per-λ absorption/scattering ratio `K/S` and those ratios are mixed linearly (`(K/S)mix = Σ v·K/S`), vs the two-constant engine's separate `Kmix`/`Smix`. From the mixed `K/S` the pipeline is shared with `CustomKmEngine`: `kmReflectance` → `saundersonToMeasured` → `spectrumToColour`. Its `inverse` is a self-contained palette-constrained subset search (per-medium partition, coarse 1/12 simplex grid + successive refinement, best-first-by-ΔE00 / fewer-paints-on-tie ranking, honest target-level out-of-gamut flag, topK truncation), reusing the exported `deltaE2000Xyz` metric and engine-internal `recipeProvenance`. New `lib/src/ab/ab_harness.dart` — `ABHarness`/`ABReport`: drives any labelled set of engines through the one interface on a shared swatch set and reports each engine's best-recipe ΔE00 per swatch plus the mean (the headline A/B number). Barrel exports `ab/ab_harness.dart`.
- **File-list reconciliation:** the plan listed `spectral_baseline_engine.dart, ab/ab_harness.dart`. Also touched: `lib/pigment_km.dart` (+1 export line for the harness) and `test/engine_test.dart` (the old "stubs throw UnimplementedError" baseline test is now wrong — replaced with the real baseline test group; the now-unused `_behavesAsUnimplementedStub` helper removed).
- **Interface decisions:** the baseline is a *reference* model, not the product engine, so it deliberately omits the TUNE chroma penalty (a product lever) and predicts in the paint's native **wet** state only (the wet/dry toggle is a product display lever). Both are documented on the class. The baseline's `inverse` is not bound by SOLVER-7's subset budget (it is an eval tool, not on the hot product path); on the shipped 3-paint palettes this is moot.
- **Verification** (BASE `8eb47a5`; `export PATH="$HOME/development/flutter/bin:$PATH"` first). `dart analyze` → clean on touched files (one pre-existing `info` in `test/chroma_penalty_test.dart`, untouched). `dart test` → **207 passed / 7 skipped**. `dart test test/acceptance -x stretch` → **29 passed / 5 skipped** (AC-25 live & green; the 5 skips are the genuinely-pending AC-11/12/21 + the two @stretch S6). Coverage gate (`tool/coverage_gate.sh 8eb47a5`) → **PASS**: `spectral_baseline_engine.dart` 117/117, `ab/ab_harness.dart` 24/24, `pigment_km.dart` no executable lines. New unit tests: a 10-test `SpectralBaselineEngine` group in `test/engine_test.dart` (single-constant-vs-two-constant divergence control, ranking, cross-medium partition, OOG, tie-break, refinement bounds, resolver branches) + 4 tests in `test/ab_harness_test.dart` (per-swatch report + mean, empty-palette→∞, unknown-label throw, zero-swatch mean throw).
- **Augmentations:** none. AC-25's test was frozen grade-A at the test review with no scheduled augmentation (it is not in the ITEST *Test augmentations* table), so it was un-pended unchanged (delete its `pendingACs` row; add the `unpendedACs` row). Pending-gate bijection kept exact (20 un-pended / 7 pending).
- **Grade gate:** fresh independent adversarial grader (G1–G6, given the PROD-2 grid) → **20 A, 0 B, 0 downgrades, 0 fixes**. AC-25 A: mutation-confirmed it rejects a baseline that throws (not wired), returns empty (`.first`), or returns negative/NaN ΔE00 (`isNonNegative`/`isFinite`). The grader noted — and accepted — that AC-25 deliberately does **not** assert the two engines' distances *differ* (an identical baseline would pass): the AC requires interchangeability + per-swatch reporting, not divergence, so this is not a G5 gap. No carried AC regressed: the diff is additive (two new/filled lib files + one export); `CustomKmEngine`, `inverse.dart`, `forward.dart`, the types — the surface every other AC drives — are byte-identical to BASE.
- **Fix passes:** 0/3 (first full run green across analyze, unit+coverage, acceptance, grade).

**Checkpoint / Handoff.**
- **Frozen interface:** `MixingEngine` (`forward`/`reflectanceOf`/`inverse`) is now implemented by **both** `CustomKmEngine` (two-constant, product) and `SpectralBaselineEngine` (single-constant, reference) and is frozen. `ABHarness({engines, palette, opts}).run(swatches) → ABReport` with `deltaE00For(label)` / `meanDeltaE00For(label)` / `engines` / `swatchCount` (both barrel-exported).
- **Known gaps:** none for AC-25. The baseline's match *accuracy* on real data is out of scope (it is the deliberately-simpler reference arm); the A/B *fidelity* comparison on real pigments rides on the dataset gates (G-3/G-4), not on this phase.
- **Module PROD is complete** (PROD-2 ✅, PROD-3 ✅). PROD-3 closes one of SIGNOFF-1's four dependencies; the remaining three (DATA-7/G-3, STRETCH-3/G-7 — and TUNE-4 already done) gate sign-off.
- **Verification commands (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"` first. `dart analyze`; `dart test`; coverage `bash tool/coverage_gate.sh <BASE>`; acceptance default `dart test test/acceptance -x stretch`; run-pending `PIGMENT_KM_RUN_PENDING=true dart test test/acceptance -x stretch`.
