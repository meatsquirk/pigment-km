# Module SOLVER — the inverse solver

**Status:** In progress — SOLVER-4 ✅ (honest out-of-gamut flag live; AC-18 ✅); next SOLVER-5 (AC-19 cross-medium)
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/engine/inverse.dart` (subset enumeration, per-subset optimizer, ranking, out-of-gamut, medium partition), `lib/src/engine/custom_km_engine.dart` (`inverse`)
**Depends on:** FORWARD · **Blocks:** TUNE, PROD

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 2 (SOLVER-2) | behavior | AC-16 | ✅ Done | 9.98M | 17m 22s (1h 13m) |
| 3 (SOLVER-3) | behavior | AC-15 | ✅ Done | 14.65M | 26m 58s (3h 30m) |
| 4 (SOLVER-4) | behavior | AC-18 | ✅ Done | 8.64M | 16m 37s (17m 34s) |
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

### Result · Checkpoint

**Result (SOLVER-3 · AC-15).** The ranking in `lib/src/engine/inverse.dart` now
runs a named comparator `_byDeltaThenFewerPaints`: best-first by ΔE00, and on an
**exact** ΔE00 tie the recipe with fewer paints wins (`(deltaE00, parts.length)`
lexicographic). The tie-break fires only on bit-equal ΔE00, so the ranking stays
strictly ΔE00-monotonic (the base test's `recipes[i].deltaE00 >=
recipes[i-1].deltaE00` holds) — it reorders only genuine ties, never near-misses.
It runs **before** the `topK` truncation, so the simplest recipes survive the cut.
AC-15 un-pended (deleted from `pending.dart`; added to `unpendedACs` in
`pending_gate_test.dart`).
- **Augmentation closed (TestAC15 → SOLVER-3):** added the constructed
  guaranteed equal-ΔE00 tie to `TestAC15_RankedPreferFewer`. Six
  identical-reflectance twin paints make every subset predict a **bit-identical**
  colour (the two-constant sum narrows to the spectrum's Float32 precision in
  `mixTwoConstant`, swamping the ~1e-16 accumulation error), so all C(6,1..4)=56
  candidates tie EXACTLY on ΔE00. Six (not three) is deliberate: 56 candidates
  exceed Dart `List.sort`'s 32-element insertion-sort threshold → the sort runs
  the **unstable** quicksort, so only an explicit prefer-fewer key yields a
  non-decreasing paint-count ranking. Verified the discrimination: reverting the
  comparator to the pre-phase ΔE00-only `sort` makes both the acceptance and the
  unit tie tests FAIL; restoring `_byDeltaThenFewerPaints` makes them pass. (The
  first attempt used 3 twins / 7 candidates — the stable-sort regime, where a
  no-tie-break solver passed too; the grade gate's fresh grader caught this as a
  G5 / augmentation-non-discrimination B, fixed in-phase.)
- **Verification (all green):** `dart analyze` → No issues · unit+acceptance
  `dart test` → **130 passed / 19 skipped / 0 failed** (new SOLVER-3 unit group in
  `engine_test.dart`: exact-tie fewer-first + topK-truncation-keeps-simplest) ·
  acceptance default `dart test test/acceptance` → **16 passed / 19 skipped**
  (AC-15 base + constructed-tie both live) · coverage gate (vs BASE `8fe6466`) →
  **PASS** (`inverse.dart` 113/113 lines; +4 lines all the new comparator, both
  arms covered — `byDelta != 0` by the distinct-paint solves, `== 0` by the twin
  tie). Line-only metric (CORE deviation) as before.
- **Grade gate:** fresh independent adversarial subagent, G1–G6, given the prior
  grids → **8 A, 0 B** (AC-15 A; AC-1/2/3/4/5/14/16 re-confirmed A — SOLVER-3
  touched no colour/km/forward/harness code, and AC-16's membership check is
  order-independent under topK). Initial pass flagged AC-15 B (3-twin augmentation
  did not discriminate); fixed and re-verified A. Grid: `behavior-test-completeness-pigment-km-engine.md` → *Behaviour re-grade — SOLVER-3*.
- **Augmentations:** TestAC15 closed (above). None newly enabled for other ACs
  (AC-22's tie-break is TUNE-2's own and uses a differing-chroma tie).
- **Fix passes:** 1/3 (the AC-15 3-twin→6-twin discrimination fix). **Tokens /
  time:** see dashboard.

**Checkpoint / Handoff.**
- **Frozen interface (unchanged surface):** `CustomKmEngine.inverse` →
  `solvePaletteConstrained` still; ranking is now `(ΔE00 asc, paint count asc)` on
  exact ties. No signature or export change. `_byDeltaThenFewerPaints` is private.
- **Verification commands (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"`
  first. `dart analyze`; `dart test`; coverage `bash tool/coverage_gate.sh <BASE>`;
  acceptance default `dart test test/acceptance`.
- **For SOLVER-4 (AC-18, out-of-gamut):** replace the `outOfGamut: false`
  placeholder in `_bestRecipeForSubset` with the honest flag — when the best
  achievable ΔE00 exceeds `MixOptions.gamutThreshold` (default 5.0), set
  `outOfGamut true`, keep the true distance, never claim a match (SI fixed intent).
  `TestAC18_OutOfGamut` (pending, owner SOLVER-4) already pins the control (pure
  green unreachable → flagged + ΔE00 > 5) and AC-17 the in-gamut partner.
  Known gaps still open: single-medium palette assumed (SOLVER-5); basic grid
  optimizer, ΔE00 ≤ 5 accuracy (SOLVER-6); no perf cap (SOLVER-7).

## Phase 4 — SOLVER-4: out-of-gamut handling (AC-18)

- **Kind:** behavior · **Target AC:** AC-18 (full) · **Depends on:** SOLVER-3 · **Blocks:** SOLVER-5
- **Files:** `inverse.dart`
- **Tasks:** when best ΔE00 > gamut ceiling, flag `outOfGamut`, keep the true distance, never claim a match (SI fixed intent).
- **Exit criteria:** analyze clean; 100% touched; unreachable target flagged; in-gamut target not flagged (control).
- **Acceptance gate:** un-pend AC-18; `TestAC18_OutOfGamut` green.

### Result · Checkpoint

**Result (SOLVER-4 · AC-18).** Out-of-gamut is now an **honest, target-level**
verdict in `solvePaletteConstrained` (`lib/src/engine/inverse.dart`). After the
ranking + topK cut, `ranked.first.deltaE00` (the best achievable distance) is
compared to `opts.gamutThreshold` (default 5.0): when it exceeds the ceiling no
palette mixture can reach the target, so **every** returned recipe is mapped
through the new private `_flaggedOutOfGamut` — `outOfGamut: true` and the verdict
relabelled `"out of gamut — nearest ΔE00 X.XX"`, with `parts`, `colour`,
`deltaE00` and `provenance` carried through unchanged so the distance stays
honest and never reads as a match (SI fixed intent). When the best is within the
ceiling the target is reachable and the set returns unflagged, so a weaker
in-top-K alternative is not mislabelled.
- **Design deviation from the prep note (improvement):** the note suggested
  swapping the `outOfGamut: false` placeholder *inside* `_bestRecipeForSubset`
  (per-recipe). That would flag any single recipe over 5 even for a reachable
  target and break the in-gamut control (`engine_test` `outOfGamut isFalse`). The
  AC is "no *mixture* can reach the target", i.e. a property of the **best**, so
  the flag is computed once on `ranked.first` and applied set-wide. `Recipe` is
  immutable, so a re-stamp helper is used rather than mutation.
- **Acceptance:** un-pend AC-18 (deleted from `pendingACs`, added to
  `unpendedACs` → SOLVER-4). `TestAC18_OutOfGamut` green default + run-pending.
  **Augmented in-phase** (strengthen-only, AC-18's own Then, G6-safe): also
  asserts the relabelled verdict reads "out of gamut", pinning "never reports it
  as a match" (previously only the flag covered it) — closes a grader flag.
- **Verification:** `dart analyze` clean · `dart test` **133 passed / 18 skipped
  / 0 failed** (new `engine_test` group "out-of-gamut honesty": saturated-green
  target flagged + never-a-match; reachable target leaves a beyond-ceiling
  alternative unflagged → rejects a per-recipe flag) · acceptance default
  `dart test test/acceptance` **17 passed / 18 skipped** · coverage gate (vs BASE
  `02d19ae`) **PASS** (`inverse.dart` **122/122** lines; +9 lines all covered —
  the oog branch both ways, `_flaggedOutOfGamut` body). Line-only metric as before.
- **Grade gate:** fresh independent adversarial subagent, G1–G6, given the prior
  grids → **9 A, 0 B** (AC-18 A; AC-1/2/3/4/5/14/15/16 re-confirmed A — SOLVER-4
  is a working-tree change touching only `inverse.dart` + the pending/unit files,
  and the re-stamp preserves order/distance/parts, so no neighbour shifts). Fix
  passes **0/3** (passed first run). Grid: `behavior-test-completeness-pigment-km-engine.md`
  → *Behaviour re-grade — SOLVER-4*.
- **Augmentations:** none owed to other ACs. Carried flags (no grade change): the
  **AC-17/AC-18 pairing** closes when SOLVER-6 un-pends AC-17 (the in-gamut
  non-flagging behaviour exists now); and a **yardstick cross-check** on
  `best.deltaE00` could further pin "honest" — AC-18's own, deferred (optional).

**Checkpoint / Handoff.**
- **Frozen interface (unchanged surface):** `CustomKmEngine.inverse` →
  `solvePaletteConstrained`, same signature/exports. `outOfGamut` is now set
  honestly; `_flaggedOutOfGamut` is private. Out-of-gamut is target-level (keyed
  on the best recipe), applied to the whole returned set.
- **Verification commands (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"`
  first. `dart analyze`; `dart test`; coverage `bash tool/coverage_gate.sh <BASE>`;
  acceptance default `dart test test/acceptance`.
- **For SOLVER-5 (AC-19, cross-medium):** partition the palette by medium, search
  each separately, never emit a recipe spanning media (§4.3). Current code assumes
  a single-medium palette (`medium = palette.first.medium`); SOLVER-5 replaces
  that with the per-medium partition. The oog flag stays as-is (applies per solve).
  Known gaps still open: basic grid optimizer / ΔE00 ≤ 5 accuracy (SOLVER-6); no
  perf cap (SOLVER-7).

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
