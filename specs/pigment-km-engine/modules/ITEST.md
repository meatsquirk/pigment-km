# Module ITEST — acceptance integration suite

**Status:** 🔄 In progress (ITEST-1 ✅)
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `test/acceptance/*` (harness, fixtures, pending gate, one test per AC), `test/acceptance/fixtures/*`
**Depends on:** CORE-2, DATA-1 (shells) · **Blocks:** every behavior phase (via G-2)

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 1 (ITEST-1) | acceptance-tests | — (harness) | ✅ Done | 5.53M | 12m 21s |
| 2 (ITEST-2) | acceptance-tests | AC-1..9 | ✅ Done | 10.94M | 30m 21s |
| 3 (ITEST-3) | acceptance-tests | AC-10..18 | ✅ Done | 10.79M | 22m 28s |
| 4 (ITEST-4) | acceptance-tests | AC-19..27 | ⬜ Todo | | |
| 5 (ITEST-5) | test-review | — | ⬜ Todo | | |

## Interface reconciliation
- **Boundary:** the package's public API only (`lib/pigment_km.dart` exports) — `spectrumToColour`/gamut-map, `kmReflectance`/`kmFunction`/`saunderson`, `MixingEngine.forward`/`inverse`/`reflectanceOf`, `PigmentTable.load`, the value types. No test reaches into `lib/src` internals. Engines assembled exactly as a consumer would (the same construction the README documents) — the only non-test code this module may touch is that one shared constructor; the coverage gate applies to it.
- **Observation points:** `forward`→`ColourValue`; `inverse`→`List<Recipe>` (parts, deltaE00, outOfGamut, provenance, medium, verdict); `reflectanceOf`→`Spectrum` for spectral Thens (AC-26); `PigmentTable.load` for the pigment fields (AC-6/8/11).
- **Pending gate:** a `pendingACs` map (AC → owning phase) + `ac(String acId)` helper that calls `markTestSkipped` unless `Platform.environment['PIGMENT_KM_RUN_PENDING'] == 'true'`. Un-pend = delete that AC's map row. `@stretch` (AC-26/27) additionally tagged so `dart test -x stretch` excludes them until G-7.

## Phase 1 — ITEST-1: harness

- **Kind:** acceptance-tests · **Target AC:** — · **Depends on:** CORE-2, DATA-1 · **Blocks:** ITEST-2/3/4
- **Files:** `test/acceptance/harness.dart`, `fixtures/*`, `pending.dart`, `smoke_test.dart`
- **Tasks:** Given/When/Then vocabulary; the 6 fixtures (synthPigments, refSpectrumColour, oogColour, acrylicPublished-placeholder, oilMixtures-placeholder, illuminants); `pendingACs` with **all 27 ACs** pending; default + run-pending targets; a never-pending smoke test proving the engine constructs and `forward` of the synthetic white returns a near-white through the public surface.
- **Exit criteria:** `dart test test/acceptance` green (everything pending-skipped except smoke); the pending map lists all 27 AC→phase keys and the test asserts its size == 27 and each key names a real phase (no vacuous pass); deterministic (no sleeps).

### Result · Checkpoint

**Result.** Acceptance harness stood up over the wired CORE-2/DATA-1 shells; no behaviour, no `lib/` touched (all new files under `test/acceptance/`).

- **Landed:**
  - `test/acceptance/harness/pending.dart` — the pending gate: `pendingACs` map (all **27** ACs → owning behaviour phase, per the build order), a closed `behaviourPhases` set (27 members), `runPending` (reads `PIGMENT_KM_RUN_PENDING`), and `ac(acId)` which `markTestSkipped`s a pending AC unless run-pending is on. A behaviour phase un-pends by deleting its map row.
  - `test/acceptance/harness/fixtures.dart` — the 6 fixtures, all through the public surface: `synthPigments()`/`synthWhite()` (via `PigmentTable.load`), `perfectDiffuser` (R=1×31), `refSpectrumColour` (perfect diffuser → D65 white point XYZ (0.95047,1,1.08883)/sRGB white), `oogColour` (pure-green sRGB(0,1,0), XYZ + OKLCh C≈0.295 — unreachable by the muted synthetic palette), and three **explicit placeholders** flagged `isReal:false`/`isPlaceholder:true`: `acrylicPublishedPlaceholder` (G-3/DATA-5), `oilMixturesPlaceholder` (G-4/DATA-6), `illuminants` (Planckian 6500 K/2856 K stand-ins; real SPDs at G-7).
  - `test/acceptance/harness/harness.dart` — one-import barrel (re-exports fixtures + pending) + Given/When/Then vocabulary (`customEngine`/`baselineEngine`/`givenAcrylicTable`/`givenOilTable`), public surface only.
  - `test/acceptance/pending_gate_test.dart` — the anti-vacuous guard (never pending): pins `pendingACs` size==27, exact keys AC-1..AC-27, and the bijection `values.toSet()==behaviourPhases`.
  - `test/acceptance/smoke_test.dart` — never-pending shell-stage wiring proof: both engines construct via the barrel; both tables load medium-tagged on the 31-grid; `forward`/`reflectanceOf` reachable and throw the **documented** `UnimplementedError`; the fixtures construct (incl. warm<neutral@400 nm / warm>neutral@700 nm SPD ordering).
- **Drift from the task (reported, resolved honestly):** the task named a smoke "forward of synthetic white returns near-white"; `forward` is an `UnimplementedError` stub until FORWARD, so the smoke asserts the genuine wiring proof available now (construct + load + documented-error reachable) and the near-white assertion is scheduled for **FORWARD-3** (see Checkpoint). Documented in the smoke's top NOTE + inline.
- **Verification (green):** `dart analyze` → No issues · `dart test` → **61/61** · acceptance default `dart test test/acceptance` → **7/7** · acceptance run-pending → **7/7** (no per-AC tests yet, so default == run-pending). Coverage gate **N/A** — no `lib/` source touched (harness is all test code); the gate script also errors on an empty changed-set under `set -u` (scaffold-tool gap, noted below).
- **Grades:** fresh independent subagent grader (G1–G6 + harness rubric: no vacuous passes / honest comments / deterministic) → **5 A / 0 B** across all 5 files; one optional hardening applied (`expect(pendingACs, hasLength(27))` atop the owners test so it is self-sufficient).
- **Fix passes:** 0/3 (passed first run; 9 post-run `info` lints — `omit_local_variable_types`, `directives_ordering` — cleaned to keep `dart analyze` at zero, counted as authoring).
- **Tokens / Time:** 5.53M / 12m 21s.

**Checkpoint / Handoff.**
- **Frozen harness contract (ITEST-2/3/4 build on these):** import `harness/harness.dart`; call `ac('AC-n')` at the top of each AC test to honour the pending gate; un-pend = delete that AC's row in `pending.dart`. Fixtures named above are the shared inputs; extend the GWT vocabulary in `harness.dart` as scenarios need (public surface only — never reach into `lib/src`). Test files are `test/acceptance/<group>_test.dart`; helper files under `harness/` are not `_test.dart` so `dart test test/acceptance` does not run them as suites.
- **Pending gate:** `PIGMENT_KM_RUN_PENDING=true dart test test/acceptance` is the red-baseline mode. `@stretch` (AC-26/27) still to be tagged by ITEST-4 so `dart test -x stretch` excludes them until G-7.
- **Verification (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"` first. `dart analyze` · `dart test` · acceptance default/red-baseline as above.
- **Known gaps / notes:** (a) smoke `forward` case is a documented-error wiring proof → **FORWARD-3** strengthens it to synthetic-white→near-white; (b) `tool/coverage_gate.sh` crashes (`changed[@]: unbound variable`) when zero `lib/` files are touched — harmless here (nothing to cover), a future scaffold fix for phases that touch no source; (c) line-coverage-only gate (CORE-1 deviation) still applies.
- **Next:** **ITEST-2 ∥ ITEST-3 ∥ ITEST-4** — one pending test per AC + red baseline, disjoint files (AC-1..9 / AC-10..18 / AC-19..27), parallelizable. Then **ITEST-5** test review → **G-2** gates the whole behaviour stage.

## Phase 2 — ITEST-2: AC-1..9 (pending) + red baseline

- **Kind:** acceptance-tests · **Target AC:** AC-1..AC-9 · **Depends on:** ITEST-1 · **Blocks:** ITEST-5 · ∥ ITEST-3/4
- **Tasks:** write `TestAC01..TestAC09` per the master catalogue; keep each scenario's Given/When/Then as comments; run-pending to record the red baseline; grade the 9 tests.
- **Exit criteria:** suite green (new tests pending); run-pending recorded; grade grid all A (or *B pending <phase>* with an augmentation row).

### Result · Checkpoint

**Result.** The AC-1..AC-9 pending acceptance tests (`test/acceptance/ac01_09_test.dart`), each through the public surface, each gated by `skip: ac('AC-n')`.

- **Option A (user-approved 2026-10-16):** the shell stage had stubbed only the three `MixingEngine` methods, so the standalone COLOR/KM/DATA backend functions AC-1/2/3/4/8 call did not exist. Added minimal public `UnimplementedError` stubs (signatures from the COLOR/KM/DATA module plans), exported from the barrel, each naming its behaviour phase: `spectrumToColour` (COLOR-2), `gamutMap` (COLOR-3), `kmReflectance`/`kmFunction` (KM-2), `configForMedium`/`saundersonToMeasured`/`saundersonToInternal` (KM-3), `resampleOntoCanonical` (DATA-2). `test/backends_stub_test.dart` covers them 100% in the default run (acceptance pending tests are skipped there, so the stubs need unit coverage — mirrors `engine_test.dart`). The bodies are the behaviour phases' to fill; these files now also appear in those modules' *Owns*.
- **Harness bug fixed (ITEST-1 carry-over):** the pending gate used `markTestSkipped` inside the body, which records a skip but does **not** stop execution — so a pending test ran its unbuilt When and errored (8 failures, 1 skip in the first default run). Changed `ac(acId)` to return a skip-reason `String?` used as the `test(..., skip: ac('AC-n'))` argument — the body never runs when skipped. This matches the convention `test/acceptance/README.md` already documented (the ITEST-1 impl had drifted from it). Removed the now-unused `package:test` import from `pending.dart`. No other ITEST-1 test uses `ac()`, so nothing else changed.
- **CIEDE2000 yardstick:** `test/acceptance/harness/colour_math.dart` (`deltaE00`, Sharma–Wu–Dalal) — the test's *independent* colour-difference reference, so AC-1/5/7's ΔE00 thresholds are measured against a trusted metric, not the library's own.
- **Verification (green):** `dart analyze` → No issues · default `dart test` → **69 passed / 9 skipped** · default `dart test test/acceptance` → **7 passed / 9 skipped** · coverage gate → **PASS** (5 new stub files 100% lines: colour 2+2, km 4+6, data 2; barrel has no executable lines).
- **Red baseline** (`PIGMENT_KM_RUN_PENDING=true dart test test/acceptance`): **+1 / −8** — 8 fail for the right reason (each names its owning phase), **AC-6 green at baseline**. Per-AC rows in the *Red baseline* table below.
- **Grades:** fresh independent subagent (G1–G6 + harness rubric) → initial 7 A / 2 B (AC-3, AC-9). AC-3 fixed in-phase (added the physical-reflectance R∞∈[0,1] assertion that rejects the branch-sign swap — the round-trip alone can't, as the roots are reciprocals and `f(R)=f(1/R)`). AC-5 hardened (asymmetric-mix controls). **Final: 8 A, 1 B pending DATA-6** (AC-9 — its executable Then needs the MPI oil fit API + data, gated on G-4/G-5; the sanctioned exception, augmentation-tracked). Grid: `behavior-test-completeness-pigment-km-engine.md`.
- **Fix passes:** 1/3 (first full run surfaced the harness skip bug + the two B grades; fixed; re-ran green).

**Checkpoint / Handoff.**
- **Frozen for ITEST-3/4:** `skip: ac('AC-n')` is the pending convention (NOT a body call). The CIEDE2000 helper `deltaE00(Xyz,Xyz)` / `deltaE00Lab(...)` is in the harness barrel. The backend stubs now exist — ITEST-3/4's AC tests call the real public surface uniformly.
- **For the behaviour phases (un-pend = delete the AC's row in `pending.dart`):**
  - **COLOR-2** `spectrumToColour`, **COLOR-3** `gamutMap`, **KM-2** `kmReflectance`/`kmFunction`, **KM-3** `configForMedium`/`saundersonToMeasured`/`saundersonToInternal`, **DATA-2** `resampleOntoCanonical` — fill these stub bodies (signatures frozen here; change them only with a recorded reason).
  - ⚠ **AC-5 owner mismatch:** AC-5's colour-level Then goes through `CustomKmEngine.forward`, which lands in **FORWARD-2**, not KM-4 (its pending owner). KM-4 alone cannot make AC-5 green. The behaviour stage should either move AC-5's un-pend to FORWARD-2 or expose a public K,S-mixing surface for a KM-4-level assertion — a decision for G-2 / behaviour planning. Flagged, not rewired.
  - **AC-6 green at baseline:** kept pending→DATA-3 and recorded green rather than cascade-edit the ITEST-1 bijection guard in an AC phase. The G-2 reviewer may un-pend it now; otherwise DATA-3 keeps it green (its decode-from-asset switch is not observable through AC-6). Its asset-path Given (`assets/pigments/synthetic_<medium>.json`) must survive any rename by DATA-3/DATA-5.
  - **AC-7** (DATA-5) / **AC-9** (DATA-6): data-limited. AC-7 has a live Then behind a G-3 precondition — DATA-5 just switches the fixture to real data. **AC-9 is B pending DATA-6: DATA-6 must ADD the executable Then** (NNLS fit on train, held-out ΔE00 ≤ 5, coeffs ≥ 0, disjoint split), not merely flip `isReal`.
- **Verification (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"` first. `dart analyze` · `dart test` · acceptance default/red-baseline as above · `bash tool/coverage_gate.sh <BASE>` (line-only).
- **Next:** **ITEST-3 ∥ ITEST-4** (disjoint files, parallelizable), then **ITEST-5** test review → **G-2**.

## Phase 3 — ITEST-3: AC-10..18 (pending) + red baseline
- **Kind:** acceptance-tests · **Target AC:** AC-10..AC-18 · **Depends on:** ITEST-1 · **Blocks:** ITEST-5 · ∥ ITEST-2/4
- **Tasks/Exit:** as ITEST-2 for `TestAC10..TestAC18`.

### Result · Checkpoint

**Result.** The AC-10..AC-18 pending acceptance tests (`test/acceptance/ac10_18_test.dart`), each through the public surface, each gated by `skip: ac('AC-n')`.

- **Option A (ITEST-2 precedent, applied to AC-10):** AC-10's masstone–tint derivation had no public surface (the shell stage stubbed only the engine methods + the ITEST-2 COLOR/KM/ingest functions). Added the minimal public stub `deriveKsFromMasstoneTint({masstone, tints, whiteK, whiteS}) → ({k, s})` + `Tint` typedef in `lib/src/data/masstone_tint.dart` (signature from the DATA-4 module plan), exported from the barrel, throwing `UnimplementedError('… — DATA-4')`. `test/backends_stub_test.dart` covers it 100% in the default run (where the acceptance pending tests are skipped). The body is DATA-4's to fill; signature frozen here (change only with a recorded reason). The file now appears in DATA's *Owns*.
- **New fixture:** `measuredMixturesPlaceholder` ({table, mixtures?, isReal}) added to `fixtures.dart` for AC-12 — a placeholder (isReal=false, mixtures=null) FORWARD-3 populates with the real measured mixtures.
- **Independent reference maths:** added `srgbToXyz`, `srgbToOklch`, `colourFromSrgb`, `hueDiffDeg` to the harness `colour_math.dart` (standard linear-sRGB→XYZ D65 matrix + Ottosson OKLab), so solver targets carry consistent sRGB/XYZ/OKLCh and AC-13's desaturation is measured against a trusted yardstick. AC-10's two-constant KM reference (`_tintReflectance`) is local to the test — AC-10 calls **no** library KM, so the derivation is checked against wholly independent physics. All verified by the grader against known values (pure green → oogColour's XYZ/OKLCh; white → D65 white point).
- **Verification (green):** `dart analyze` → No issues · default `dart test` → **70 passed / 18 skipped** (+1 = the DATA-4 stub coverage test) · default `dart test test/acceptance` → **7 passed / 18 skipped** · coverage gate → **PASS** (`masstone_tint.dart` 2/2 lines; barrel export has no executable lines).
- **Red baseline** (`PIGMENT_KM_RUN_PENDING=true dart test test/acceptance/ac10_18_test.dart`): **−9 / +0** — every test fails for the right reason (per-AC rows below). AC-10/13/14 on their When (`UnimplementedError`), AC-15..18 on their When (`inverse — SOLVER phases`), AC-11/AC-12 on a Given precondition naming their owning phase.
- **Grades:** fresh independent subagent (G1–G6 + catalogue) → initial 6 A, 2 A (data-limited), **1 B (AC-15)**. AC-15 fixed in-phase: added `recipes.length ≥ 2` so the best-first ordering check is non-vacuous (rejects a single-recipe unranked solver); the prefer-fewer-on-tie reject is augmentation-tracked (SOLVER-3 builds a guaranteed 2-vs-3-paint tie). **Final: 9 A** (AC-11, AC-12 data-limited). Grid: `behavior-test-completeness-pigment-km-engine.md` Band 2.
- **Fix passes:** 1/3 (the AC-15 vacuity).

**Checkpoint / Handoff.**
- **Frozen for the behaviour phases (un-pend = delete the AC's row in `pending.dart`):**
  - **DATA-4** fills `deriveKsFromMasstoneTint` (signature frozen here); **DATA-7** flips `acrylicPublishedPlaceholder.isReal` + finalizes the Golden/RIT NOTICE wording and makes the real acrylic paints `Provenance.calculated` (AC-11's precondition + real-source Then); **FORWARD-3** populates `measuredMixturesPlaceholder.mixtures` with ≥1 real multi-paint mixture + published colour (AC-12).
  - **FORWARD-2** (AC-14) / **FORWARD-4** (AC-13) fill `CustomKmEngine.forward`; **FORWARD-3** (AC-12) too. **SOLVER-2/3/4/6** fill `CustomKmEngine.inverse`.
  - ⚠ **AC-15 augmentation (SOLVER-3):** the fewer-paint-on-tie rule is only exercised by a constructed equal-ΔE00 tie the solver produces — SOLVER-3 must add a 2-vs-3-paint tie case asserting the 2-paint recipe ranks first, then close the augmentation row. The `≥ 2 recipes` assertion already requires this target+palette to yield ≥2 ranked recipes.
  - ⚠ **AC-17 (SOLVER-6):** the in-gamut target `colourFromSrgb((0.72,0.76,0.86))` is assumed reachable; SOLVER-6 confirms/tunes it to a known-reachable target (G-6 adds held-out ΔE00 validation evidence).
- **Verification (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"` first. `dart analyze` · `dart test` · acceptance default/red-baseline as above · `bash tool/coverage_gate.sh <BASE>` (line-only).
- **Next:** **ITEST-4** (AC-19..27, tag AC-26/27 `@stretch`) — last AC-test band; then **ITEST-5** test review → **G-2** gates the whole behaviour stage.

## Phase 4 — ITEST-4: AC-19..27 (pending) + red baseline
- **Kind:** acceptance-tests · **Target AC:** AC-19..AC-27 · **Depends on:** ITEST-1 · **Blocks:** ITEST-5 · ∥ ITEST-2/3
- **Tasks/Exit:** as ITEST-2 for `TestAC19..TestAC27`; tag AC-26/27 `@stretch`.

### Result · Checkpoint  <!-- filled on completion -->

## Phase 5 — ITEST-5: test review (G-2)

- **Kind:** test-review · **Target AC:** — · **Depends on:** ITEST-2, ITEST-3, ITEST-4 · **Blocks:** every behavior phase
- **Preconditions:** every AC-test phase done; whole-suite grid all A (or *B pending <phase>*).
- **Tasks:** assemble the packet here (per AC: test name, Given checks, When, Then + Rejects, one line each; red-baseline summary; scheduled augmentations + closing phase; grid path + counts; what to look at first — the fidelity ACs limited until G-3/G-4). Set this phase `⏸ Awaiting review`, G-2 *awaiting decision*, record ledger, commit, stop with: `/feature-next-phase --gate pigment-km-engine G-2 approved | "<changes>"`.

### Result · Checkpoint  <!-- filled on completion -->

## Red baseline  <!-- filled by the AC-test phases -->

| AC | Test | Baseline outcome (run-pending) | Fails at | Owning phase | Grade |
|---|---|---|---|---|---|
| AC-1 | TestAC01_SpectrumToColour | fail | When — `UnimplementedError: spectrumToColour — COLOR-2` | COLOR-2 | A |
| AC-2 | TestAC02_GamutMap | fail | When — `UnimplementedError: gamutMap — COLOR-3` | COLOR-3 | A |
| AC-3 | TestAC03_KmRoundTrip | fail | When — `UnimplementedError: kmReflectance — KM-2` | KM-2 | A |
| AC-4 | TestAC04_Saunderson | fail | Given — `UnimplementedError: configForMedium — KM-3` | KM-3 | A |
| AC-5 | TestAC05_TwoConstantMix | fail | When — `UnimplementedError: CustomKmEngine.forward — FORWARD phases` | KM-4 ⚠ (colour Then needs FORWARD-2) | A |
| AC-6 | TestAC06_Artifact | **green at baseline** | — (shell loader already satisfies it) | DATA-3 | A |
| AC-7 | TestAC07_RoundTripFidelity | fail | Given precondition — real acrylic + published colours absent (G-3/DATA-5) | DATA-5 | A (data-limited) |
| AC-8 | TestAC08_Resample | fail | When — `UnimplementedError: resampleOntoCanonical — DATA-2` | DATA-2 | A |
| AC-9 | TestAC09_OilFit | fail | Given precondition — MPI oil data absent (G-4/DATA-6) | DATA-6 | B pending DATA-6 |
| AC-10 | TestAC10_MasstoneTint | fail | When — `UnimplementedError: deriveKsFromMasstoneTint — DATA-4` | DATA-4 | A |
| AC-11 | TestAC11_Attribution | fail | Given precondition — real acrylic data absent (G-3/DATA-5); LICENSE/NOTICE Thens pass | DATA-7 | A (data-limited) |
| AC-12 | TestAC12_ForwardFidelity | fail | Given precondition — real measured mixtures absent (G-3/G-4) | FORWARD-3 | A (data-limited) |
| AC-13 | TestAC13_Desaturation | fail | When — `UnimplementedError: CustomKmEngine.forward — FORWARD phases` | FORWARD-4 | A |
| AC-14 | TestAC14_Normalize | fail | When — `UnimplementedError: CustomKmEngine.forward — FORWARD phases` | FORWARD-2 | A |
| AC-15 | TestAC15_RankedPreferFewer | fail | When — `UnimplementedError: CustomKmEngine.inverse — SOLVER phases` | SOLVER-3 | A |
| AC-16 | TestAC16_PaletteOnly | fail | When — `UnimplementedError: CustomKmEngine.inverse — SOLVER phases` | SOLVER-2 | A |
| AC-17 | TestAC17_InGamut | fail | When — `UnimplementedError: CustomKmEngine.inverse — SOLVER phases` | SOLVER-6 | A |
| AC-18 | TestAC18_OutOfGamut | fail | When — `UnimplementedError: CustomKmEngine.inverse — SOLVER phases` | SOLVER-4 | A |
| … | (AC-19..27 filled ITEST-4) | | | | |

## Test augmentations  <!-- pre-seeded; confirmed by AC-test phases; closed by behavior phases -->

| AC test | Limited because | Augmented by | Add | Status |
|---|---|---|---|---|
| TestAC07 | real Golden/RIT data + published colours not yet on disk (G-3); live Then is behind a precondition that fails at baseline | DATA-5 | populate the `acrylicPublished` fixture with the shipped acrylic table + published colours (`isReal=true`); the existing Then (ΔE00 ≤ 0.5 for every paint) then runs — no test rewrite | ⬜ Open |
| TestAC09 | MPI oil data + fit API not yet on disk (G-4/G-5); **precondition-only at baseline** — graded *B pending DATA-6* | DATA-6 | **ADD the executable Then** (not merely flip `isReal`): per-λ NNLS fit on the train split, predict held-out mixtures ΔE00 ≤ 5 each, assert every fit coeff ≥ 0 at every λ, assert the train/held-out split is disjoint | ⬜ Open |
| TestAC11 | Golden/RIT attribution wording pending the permission text (G-3); real-source provenance Then (measured→Calculated) behind the `isReal` precondition | DATA-7 | finalize + assert the agreed Golden/RIT NOTICE wording (tighten "states changes" to the exact text); flip `acrylicPublishedPlaceholder.isReal`; tag the real acrylic paints `Provenance.calculated` | ⬜ Open |
| TestAC12 | measured mixtures not yet on disk (G-3/G-4); `measuredMixturesPlaceholder` is a placeholder — precondition-gated at baseline | FORWARD-3 | populate `measuredMixturesPlaceholder` (isReal=true, ≥1 real multi-paint mixture + published colour); the written ΔE00 ≤ 5 loop then runs — no test rewrite | ⬜ Open |
| TestAC15 | prefer-fewer-on-tie reject needs an equal-ΔE00 2-vs-3-paint tie only the built solver can produce; at baseline the in-test tie loop fires only on a natural tie | SOLVER-3 | add a constructed guaranteed equal-ΔE00 2-vs-3-paint tie asserting the 2-paint recipe ranks first | ⬜ Open |
| TestAC21 | real curated palette needs the acrylic data (G-3); asserts the neon-impossible property on the synthetic palette | TUNE-3 | switch to the shipped Zorn-style acrylic palette | ⬜ Open |
