# Module TUNE — natural, muted colour

**Status:** ✅ Done — TUNE-2 ✅ (AC-22 chroma penalty), TUNE-3 ✅ (AC-21 curated palette, A), TUNE-4 ✅ (AC-23 wet/dry). Module complete.
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/tune/default_palettes.dart` (curated naturalistic per-medium palettes), `lib/src/tune/chroma_penalty.dart`, `lib/src/tune/wet_dry.dart`
**Depends on:** SOLVER, DATA · **Blocks:** SIGNOFF-1

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 2 (TUNE-2) | behavior | AC-22 | ✅ Done | 14.91M | 30m 48s |
| 3 (TUNE-3) | behavior | AC-21 | ✅ Done | 15.58M | 22m 16s |
| 4 (TUNE-4) | behavior | AC-23 | ✅ Done | 8.87M | 16m 55s |

## Interface reconciliation

Design §7: curated limited real-pigment palette (lever 1, biggest), `chromaPenalty` λ_natural tie-break (lever 2, D-10), per-medium wet→dry transform (lever 3, D-12). No sRGB desaturation filter — naturalness is physics+palette.

## Open gates
- **G-2** ✅ (all behavior). **G-3** ✅ for TUNE-3 (data side cleared 2026-10-19 — the shipped `acrylic.json`/DATA-5 on the 10° basis is all the curated palette needs; attribution wording is DATA-7's).

## Phase 2 — TUNE-2: chroma penalty tie-break (AC-22)

- **Kind:** behavior · **Target AC:** AC-22 (full) · **Depends on:** SOLVER-6 · **Blocks:** —
- **Files:** `chroma_penalty.dart`, `inverse.dart` (hook)
- **Tasks:** add `λ_natural·C*(mix)` as a small tie-break regularizer, off by default in raw ΔE00 ranking.
- **Exit criteria:** analyze clean; 100% touched; penalty-on prefers lower chroma on a tie; penalty-off unchanged (control).
- **Acceptance gate:** un-pend AC-22; `TestAC22_ChromaPenalty` green.

### Result · Checkpoint

**Result (TUNE-2 · AC-22).** The chroma penalty is a tie-break regularizer that
nudges the solver toward naturalistic, muted recipes without ever trading away
visible match accuracy.
- **New module `lib/src/tune/chroma_penalty.dart`** — `naturalChromaPenalty = 1e-6`
  (λ) and `chromaPenalizedCost(recipe, λ) = recipe.deltaE00 + λ·C*`, where C* is
  the OKLCh chroma of the recipe's predicted colour (`recipe.colour.oklch.c`, the
  same chroma measure the §7 natural-colour ceiling uses). With λ=0 the cost is
  exactly ΔE00, so the penalty is off in the raw ranking.
- **`inverse.dart` hook** — the ranking comparator `_byDeltaThenFewerPaints`
  became `_byCostThenFewerPaints(a, b, λ)`: sort by `chromaPenalizedCost(·, λ)`,
  then (unchanged) fewer paints on a cost tie (AC-15). `solvePaletteConstrained`
  sets `λ = opts.chromaPenalty ? naturalChromaPenalty : 0.0`. λ is tiny by design:
  it only reorders recipes within <~1e-6 ΔE00 of each other (a genuine tie), far
  below a 1-ΔE00 JND, so the raw ΔE00 order of any visibly-different pair is
  untouched. On a tie the lower C* yields the smaller cost → the more muted recipe
  ranks first.
- **Out-of-gamut made penalty-independent.** The AC-18 verdict now reads the true
  ΔE00 **minimum** over all candidates (`bestDelta`, computed before ranking)
  instead of `ranked.first.deltaE00`, so the chroma tie-break — which may surface
  an equally-close but more muted recipe ahead of the strict ΔE00 minimum — can
  only reorder the returned list, never change whether a target is reachable.
  (For penalty-off this equals the old value exactly.)
- **Acceptance.** AC-22 un-pended (row deleted from `pending.dart`; added to
  `unpendedACs` → TUNE-2). The augmentation (ITEST *TestAC22*) was **closed with**
  the un-pend: the base test's hard `expect(sawTie, isTrue)` — over-constrained on
  an absent natural tie — was relaxed to a soft natural-tie sweep plus the live
  penalty-OFF ΔE00-monotonicity check (AC-15's base/constructed split), and a new
  **constructed-tie test** guarantees the decisive case: two identical-reflectance
  twin groups (2-paint VIVID, 3-paint MUTED) in one medium, with a bisected target
  equidistant in ΔE00; penalty-ON ranks the 3-paint MUTED recipe ahead of the
  2-paint VIVID one — a reordering a fewer-paints rule cannot produce, so it
  discriminates the chroma penalty from AC-15's tie-break.
- **Verification.** `dart analyze` → No issues · `dart test` → **172 passed / 10
  skipped** (AC-22 skip→2 passing tests + 4 new `chroma_penalty` unit tests) ·
  acceptance default `dart test test/acceptance` → **26 passed / 10 skipped** ·
  coverage gate (vs BASE `b0de35f`) → **PASS** (`inverse.dart` 148/148,
  `chroma_penalty.dart` 2/2; line-only metric, CORE deviation). No exclusive lane
  (ranking test, in-process shared lane).
- **Grade gate.** Fresh independent adversarial grader (G1–G6), given the prior
  grid → **17 A, 0 B, 0 downgrades** (AC-22 A; AC-1..6,8,10,13..20 re-confirmed —
  the λ=1e-6 penalty only reorders <1e-6-ΔE00 near-ties, which no other un-pended
  AC asserts on). Grid: *Behaviour re-grade — TUNE-2*.
- **Augmentations:** TestAC22 closed (above). None newly enabled for other ACs.
- **Fix passes:** 1/3 (first full acceptance run: the constructed-tie recipes were
  located by exact parts {0.5,0.5} — but identical-reflectance twins keep the
  optimizer's arbitrary shares, so switched to locating by paint-id set; an
  import-ordering lint was fixed before the test run). **Tokens / time:** see
  dashboard.

**Checkpoint / Handoff.**
- **Frozen interface:** `lib/src/tune/chroma_penalty.dart` — `naturalChromaPenalty`
  (λ=1e-6) and `chromaPenalizedCost(Recipe, double)`; imported by `inverse.dart`
  only, **not** exported from the barrel (a solver-internal tuning helper). The
  engine surface (`CustomKmEngine.inverse`, `MixOptions.chromaPenalty`) is
  unchanged. `MixOptions.chromaPenalty` defaults to `true` (penalty on).
- **Verification commands (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"`
  first. `dart analyze`; `dart test`; coverage `bash tool/coverage_gate.sh <BASE>`;
  acceptance default `dart test test/acceptance`.
- **Gotchas for later TUNE phases:** (1) the chroma penalty is a tie-break only
  (λ tiny) — a wet/dry or curated-palette phase that asserts a specific `.first`
  recipe should not assume strict ΔE00-min ordering under the default (penalty on);
  (2) locating a twin-subset recipe must be by **paint-id set**, not fitted
  fractions (identical reflectance → arbitrary equally-good shares). TUNE-3 (AC-21)
  shipped the real Zorn-style acrylic palette + hardened chroma ceiling (done);
  TUNE-4 (AC-23 wet/dry) done.

## Phase 3 — TUNE-3: curated default palette (AC-21) — real palette needs G-3

- **Kind:** behavior · **Target AC:** AC-21 (full) · **Depends on:** SOLVER-6, DATA-5 · **Blocks:** —
- **Files:** `default_palettes.dart`
- **Tasks:** ship the Zorn-style earth-forward acrylic default (design §7); prove no mixture exceeds the chroma ceiling, a muted target solves ≤ 5, a neon target returns out-of-gamut.
- **Exit criteria:** analyze clean; 100% touched; neon-impossible property holds.
- **Acceptance gate:** un-pend AC-21; `TestAC21_NoNeon` green; **augment** from the synthetic palette to the real one when G-3 lands.

### Result · Checkpoint  <!-- TUNE-3 ✅ 2026-10-19 -->

**Gate G-3 (TUNE-3 data side, decision — Matt Quirk 2026-10-19):** the curated
real acrylic palette needs only the shipped `acrylic.json` (DATA-5) on the 10°
basis (COLOR-4), not the attribution wording (that is DATA-7's), so TUNE-3 is
cleared to proceed.

**Result (TUNE-3 · AC-21).** Design §7 lever 1 — the biggest naturalness lever
is the palette itself, a curated limited set that physically cannot mix neon.
- **New module `lib/src/tune/default_palettes.dart`** (barrel-exported). The
  curated **Zorn-style earth-forward acrylic** palette ([curatedAcrylicPaletteIds],
  7 Golden/RIT earths): `titan_buff` (the lightener — the real table has no
  titanium white, so its warmest off-white stands in, a documented data-driven
  substitution), `yellow_ochre`, `red_oxide`, `burnt_sienna`, `burnt_umber`,
  `raw_umber`, `mars_black`. `defaultPalette(Medium.acrylic)` loads them once from
  the shipped `acrylic.json` (the real DATA-5 table, **not** the synthetic solver
  placeholder `load(Medium.acrylic)`, which the in-gamut solver ACs still own and
  which TUNE-3 leaves untouched). `defaultPalette(Medium.oil)` throws
  `UnsupportedError` (no curated oil default until G-4/DATA-6 — honest, no
  placeholder-as-curated).
- **Fixed ceiling `naturalChromaCeiling = 0.10`** (hardened down from the prior
  provisional in-test 0.25): a fixed property of naturalistic colour, discriminating
  — the curated palette's max mixture chroma ≈0.078 sits under it with real margin,
  while a vivid cadmium (OKLCh C≈0.12–0.17 through this measured-data pipeline) and
  a neon target (C≈0.30) lie above it.
- **Engine resolve.** Both `CustomKmEngine._resolve` and
  `SpectralBaselineEngine._resolve` gained a tail fallback to `defaultPaletteById`
  after the shipped medium tables, so the public `forward` can predict the curated
  real paints (which are not in the synthetic tables). No id collision (synthetic
  ids searched first; the 7 curated ids are distinct), so every existing `forward`
  resolves exactly as before — the fallback fires only for the new curated ids,
  which previously threw. Identical change to both engines keeps them drop-in
  interchangeable (AC-25).
- **Acceptance.** AC-21 un-pended (`pending.dart` row removed; added to
  `unpendedACs` → TUNE-3). The ITEST-4 augmentation (owned by TUNE-3) was made:
  the test now drives the real `defaultPalette(Medium.acrylic)` + fixed
  `naturalChromaCeiling`, checks the curated set (non-empty, length, single-medium)
  and keeps the reachable-muted / neon-out-of-gamut control pair. Independent fresh
  subagent re-grade: **A** — the prior "A (data-limited)" / provisional-ceiling flag
  is closed.
- **Gates.** `dart analyze lib test` clean (only the pre-existing
  `chroma_penalty_test:38` info, not mine). Default suite **246 pass / 3 skip**;
  run-pending red baseline **+33 −3** (AC-21 green; the 3 failures are AC-9/11/12
  on their own preconditions naming DATA-6/DATA-7/FORWARD-3). Coverage **100%** on
  all touched files (`default_palettes.dart` 14/14, `custom_km_engine.dart` 16/16,
  `spectral_baseline_engine.dart` 118/118; `pigment_km.dart` export-only). Grade
  grid: 24 A (Band 5 appended). Fix passes: 0/3.

**Checkpoint / Handoff.** Verification (repo root, `export PATH="$HOME/development/flutter/bin:$PATH"`):
`dart analyze lib test` · `dart test` (default, green) ·
`PIGMENT_KM_RUN_PENDING=true dart test test/acceptance` (red baseline) ·
`bash tool/coverage_gate.sh <BASE>`. **Frozen:** `curatedAcrylicPaletteIds`, the
`naturalChromaCeiling = 0.10` bound, `defaultPalette`/`defaultPaletteById`, and the
`_resolve` fallback in both engines. **Known gap:** no curated **oil** default yet
(`defaultPalette(Medium.oil)` throws) — awaits G-4/DATA-6 and the §7 Monet-style
MPI 8-tube set. TUNE module complete; the 3 remaining pending ACs (AC-9/11/12) are
unrelated to TUNE.

## Phase 4 — TUNE-4: wet/dry transform (AC-23)

- **Kind:** behavior · **Target AC:** AC-23 (full) · **Depends on:** SOLVER-6 · **Blocks:** SIGNOFF-1
- **Files:** `wet_dry.dart`, `custom_km_engine.dart` (toggle)
- **Tasks:** per-medium wet→dry offset (D-12, default wet) applied as a **post-prediction state transform** (G-2 2026-10-16 — `forward`/`inverse` stay option-free, the rejected alternative being `forward(mix, opts)`); re-render colour without re-solving (parts & ΔE00 unchanged); acrylic dry darker + hue-shifted. The `MixOptions.wet` toggle is read through `inverse`, not an argument to `forward`.
- **Exit criteria:** analyze clean; 100% touched; dry≠wet by the documented offset; parts unchanged.
- **Acceptance gate:** un-pend AC-23; `TestAC23_WetDry` green.

### Result · Checkpoint

**Result (TUNE-4 · AC-23).** The wet/dry toggle is a post-prediction display
state, not a solver parameter — the solve always works in the paint's wet
(native-prediction) state, and the dry state re-renders each recipe's colour by
the medium's documented drying offset without re-solving.
- **New module `lib/src/tune/wet_dry.dart`** — `toDryState(Recipe, WetDryTransform)`
  carries parts/ΔE00/provenance/outOfGamut/verdict through unchanged and re-renders
  only `colour` via `driedColour(ColourValue, WetDryTransform)`: XYZ → CIELAB →
  L*C*h, add the transform's `lightnessDelta`/`chromaDelta` (clamped ≥ 0)/
  `hueDeltaDeg` (wrapped to `[0,360)`), back to CIELAB → XYZ, then rebuild a
  consistent sRGB/XYZ/OKLCh triple with the colour backend's own matrices
  (`oklch.dart`, no duplicated constants). The identity transform short-circuits
  (returns the input unchanged). Because L* alone sets Y, a negative lightness
  delta darkens (lowers Y) regardless of the chroma/hue deltas.
- **`saunderson.dart`** — acrylic's `MediumConfig` now carries a documented
  non-identity `WetDryTransform(lightnessDelta: -3, chromaDelta: 1.5, hueDeltaDeg: 3)`
  (dry is darker, slightly deeper, hue-shifted); oil stays `WetDryTransform.none`,
  honestly deferred until the MPI oil drying data (G-4/G-5). Documented-defaults
  pattern (like `k1,k2`): the AC asserts the offset's *direction*, not the literals.
- **`custom_km_engine.dart`** — `CustomKmEngine.inverse` reads `opts.wet`: when
  true it returns `solvePaletteConstrained` unchanged (the option-free solve, gate
  G-2); when false it maps each recipe through `toDryState(r, configForMedium(r.medium).wetDry)`.
  `forward`/the solve stay option-free; the wet/dry choice is read through `inverse`.
- **Acceptance.** AC-23 un-pended (row deleted from `pending.dart`; added to
  `unpendedACs` → TUNE-4 in `pending_gate_test.dart`). `TestAC23_WetDry` green in
  the default run. No augmentation was scheduled for AC-23, and the behaviour
  enables none for other ACs (the transform fires only on the non-default dry
  path, which no other AC test exercises).
- **Verification.** `dart analyze` → clean (exit 0; the one pre-existing `info`
  is TUNE-2's test file, untouched). `dart test` → **185 passed / 9 skipped**;
  `dart test test/acceptance` → **27 passed / 9 skipped** (the 9 still-pending
  ACs). Coverage gate (vs BASE `da7cdb4`) → **PASS**: `wet_dry.dart` 47/47,
  `saunderson.dart` 19/19, `custom_km_engine.dart` 15/15 (line metric, CORE
  deviation). No exclusive lane (pure in-process colour maths).
- **Grade gate.** Fresh independent adversarial grader (G1–G6), given the TUNE-2
  grid → **18 A, 0 B, 0 downgrades**. AC-23 A; AC-1..6,8,10,13..22 re-confirmed
  (the dry transform is inert on every default-`MixOptions()` path, so carried
  colours are byte-identical to BASE). Grid: *Behaviour re-grade — TUNE-4*.
- **Fix passes:** 0/3 (first full run green across analyze, unit+coverage,
  acceptance and grade; the only follow-up was registering AC-23 in `unpendedACs`
  so the pending-gate bijection stayed exact — not a gate failure). **Tokens /
  time:** see dashboard.

**Checkpoint / Handoff.**
- **Frozen interface:** `lib/src/tune/wet_dry.dart` — `toDryState(Recipe, WetDryTransform)`
  and `driedColour(ColourValue, WetDryTransform)`; imported by `custom_km_engine.dart`
  only, **not** barrel-exported (a solver-internal display helper, like
  `chroma_penalty.dart`). The engine surface (`CustomKmEngine.inverse`,
  `MixOptions.wet` default `true`) is unchanged; `configForMedium(medium).wetDry`
  is the public per-medium offset the AC reads.
- **Verification commands (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"`
  first. `dart analyze`; `dart test`; coverage `bash tool/coverage_gate.sh <BASE>`;
  acceptance default `dart test test/acceptance`.
- **Gotchas for later phases:** (1) a solve returns **wet** colours by default
  (`MixOptions.wet` defaults true); only `MixOptions(wet: false)` re-renders, and
  only `CustomKmEngine` applies it — the baseline engine (PROD-3/AC-25) carries no
  drying offset. (2) The acrylic offset literals (`-3/1.5/3`) are documented
  defaults pending G-5; TUNE-3's real curated palette (G-3) does not change them.
  (3) oil's drying offset is still `WetDryTransform.none` — DATA-6/G-4/G-5 may set
  it when the MPI oil data lands. TUNE-3 (AC-21) remains gated on G-3; the TUNE
  module's only remaining phase is TUNE-3.
