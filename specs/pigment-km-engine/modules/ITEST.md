# Module ITEST — acceptance integration suite

**Status:** ✅ Done (ITEST-1..5 ✅; G-2 approved 2026-10-16 — behaviour stage open)
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `test/acceptance/*` (harness, fixtures, pending gate, one test per AC), `test/acceptance/fixtures/*`
**Depends on:** CORE-2, DATA-1 (shells) · **Blocks:** every behavior phase (via G-2)

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 1 (ITEST-1) | acceptance-tests | — (harness) | ✅ Done | 5.53M | 12m 21s |
| 2 (ITEST-2) | acceptance-tests | AC-1..9 | ✅ Done | 10.94M | 30m 21s |
| 3 (ITEST-3) | acceptance-tests | AC-10..18 | ✅ Done | 10.79M | 22m 28s |
| 4 (ITEST-4) | acceptance-tests | AC-19..27 | ✅ Done | 6.34M | 16m 10s |
| 5 (ITEST-5) | test-review | — | ✅ Done (G-2 approved) | 2.27M | 5m 13s |

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
  - ⚠ **AC-5 owner mismatch → resolved by G-2 (2026-10-16):** AC-5's colour-level Then goes through `CustomKmEngine.forward` (FORWARD-2), not KM-4. **G-2 moved AC-5's un-pend to FORWARD-2**; KM-4 stays the two-constant-mixing enabler (no new public K,S surface). FORWARD-2 un-pends AC-5 and makes `TestAC05_TwoConstantMix` green.
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

### Result · Checkpoint

**Result.** The AC-19..AC-27 pending acceptance tests (`test/acceptance/ac19_27_test.dart`), the last AC-test band, each through the public surface, each gated by `skip: ac('AC-n')`. No `lib/` touched — this phase adds only test files + a tag declaration.

- **No Option-A stubs needed:** every AC-19..25 scenario drives the already-frozen public surface (`inverse`, `forward`, `configForMedium`, the `MixingEngine` interface, `Recipe`/`MixOptions`/`Provenance`/`WetDryTransform`, the public `Pigment` constructor). The two @stretch ACs (AC-26/27) are deliberately NOT given a frozen glazing/metamerism API — their scope is gated behind the still-open **G-7**; each body asserts a scope precondition (`_stretchScopeApproved` const `false`) naming G-7, with the full Given/When/Then/Rejects documented in-place for STRETCH-2/3 to implement once scope is approved.
- **`@stretch` tagging:** AC-26/27 carry `tags: 'stretch'`; new `dart_test.yaml` declares the tag so `dart test -x stretch` excludes them warning-free (verified −7 excluded).
- **Verification (green):** `export PATH="$HOME/development/flutter/bin:$PATH"` first. `dart analyze test/acceptance/ac19_27_test.dart` → No issues · default `dart test test/acceptance` → **7 passed / 27 skipped** (all 27 ACs now pending-skipped) · full `dart test` → **70 passed / 27 skipped** · coverage gate **N/A** (no `lib/` source touched — test-only change, as ITEST-1).
- **Red baseline** (`PIGMENT_KM_RUN_PENDING=true dart test test/acceptance/ac19_27_test.dart`): **−9 / +0** — every test fails for the right reason (per-AC rows in the *Red baseline* table). AC-19/22/23/24/25 on the `inverse` When, AC-20 on `inverse`, AC-21 on the `forward` When, AC-26/27 on a Given scope precondition naming G-7.
- **Grades:** fresh independent subagent (G1–G6 + catalogue, matched to Band 1/2) → **6 A, 1 A (data-limited: AC-21), 2 B pending (AC-26→STRETCH-2, AC-27→STRETCH-3)** — no G-rule failures; all downgrades are the rubric's sanctioned gate/data deferrals. Grid: `behavior-test-completeness-pigment-km-engine.md` Band 3. Augmentation rows added for AC-21/22/26/27.
- **Fix passes:** 0/3 (passed first run; the two Bs are the sanctioned *B pending <phase>* exception behind open G-7, not in-phase-fixable).

**Checkpoint / Handoff.**
- **Frozen for the behaviour phases (un-pend = delete the AC's row in `pending.dart`):** SOLVER-5 (AC-19), SOLVER-7 (AC-20), TUNE-3 (AC-21), TUNE-2 (AC-22), TUNE-4 (AC-23), PROD-2 (AC-24), PROD-3 (AC-25); STRETCH-2 (AC-26) / STRETCH-3 (AC-27) only after G-7.
- **Carry-forward flags for owning phases (from the grader):**
  - ⚠ **AC-19 (SOLVER-5):** add a constructed cross-medium-tempting target as a control (the test uses a generic grey target; the catalogue's explicit control isn't built).
  - ⚠ **AC-21 (TUNE-3):** confirm/tune the *real* naturalistic chroma ceiling — the test trusts a provisional in-test ceiling (0.25) on the synthetic palette and does **not** gate behind an `isReal` precondition; TUNE-3 must ship the curated palette **and** harden the ceiling.
  - ⚠ **AC-22 (TUNE-2):** construct the guaranteed equal-ΔE00 2-vs-3-paint tie the test's `expect(sawTie, isTrue)` depends on, **together with** the un-pend — until then the test is over-constrained on an absent natural tie (same AC-15/SOLVER-3 treatment).
  - ⚠ **AC-23 wet/dry interface → resolved by G-2 (2026-10-16):** wet/dry is a **post-prediction state transform** — `forward`/`inverse` stay option-free; the test reads wet/dry via `inverse(MixOptions.wet)`+`Recipe.colour`. TUNE-4 applies the per-medium wet→dry offset after prediction so parts & the chosen recipe are stable across states. (`forward(mix, opts)` was the rejected alternative.)
- **Verification (reuse):** `dart analyze` · `dart test` · acceptance default/red-baseline as above · `dart test -x stretch` excludes AC-26/27.
- **Next:** **ITEST-5** — the test review (assemble the packet, set `⏸ Awaiting review`, G-2 *awaiting decision*). Preconditions now met: all three AC-test phases done; whole-suite grid all A or *B pending <phase>* with an augmentation row. G-2 gates the whole behaviour stage.

## Phase 5 — ITEST-5: test review (G-2)

- **Kind:** test-review · **Target AC:** — · **Depends on:** ITEST-2, ITEST-3, ITEST-4 · **Blocks:** every behavior phase
- **Preconditions:** every AC-test phase done; whole-suite grid all A (or *B pending <phase>*).
- **Tasks:** assemble the packet here (per AC: test name, Given checks, When, Then + Rejects, one line each; red-baseline summary; scheduled augmentations + closing phase; grid path + counts; what to look at first — the fidelity ACs limited until G-3/G-4). Set this phase `⏸ Awaiting review`, G-2 *awaiting decision*, record ledger, commit, stop with: `/feature-next-phase --gate pigment-km-engine G-2 approved | "<changes>"`.

### Result · Checkpoint

**Status: ✅ Done — G-2 approved 2026-10-16 11:08 EDT by Matt Quirk.** The full acceptance suite (one pending integration test per AC, ITEST-2/3/4) was approved as assembled; no changes requested. Routing decisions recorded at G-2: (1) **AC-23** wet/dry = post-prediction state transform — `forward`/`inverse` stay option-free, TUNE-4 re-renders colour without re-solving (parts stable across states); (2) **AC-5** un-pend moves **KM-4 → FORWARD-2** (FORWARD-2's `forward` makes the colour-level Then green; KM-4 remains the two-constant-mixing enabler). The behaviour stage is open: COLOR-2 ∥ KM-2 ∥ DATA-2 startable. No `lib/` or test code changed this phase — a review-only session.

**Preconditions met (verified live this session):**
- All three AC-test phases (ITEST-2/3/4) ✅ Done; all 27 ACs have one pending test through the package's **public surface only** (no reach into `lib/src`).
- Whole-suite grade grid: **24 A / 3 B-pending** — 20 full A, 4 A (data-limited: AC-7/11/12/21), 3 *B pending <phase>* (AC-9→DATA-6, AC-26→STRETCH-2, AC-27→STRETCH-3). Every B/data-limit is the rubric's **sanctioned gate/data deferral**, not a design miss — no G-rule failures. Grid: [`../behavior-test-completeness-pigment-km-engine.md`](../behavior-test-completeness-pigment-km-engine.md) (Bands 1/2/3, each graded by a fresh independent adversarial subagent, 2026-10-16).
- Live re-run (`export PATH="$HOME/development/flutter/bin:$PATH"`): `dart analyze` → No issues · default `dart test` → **70 passed / 27 skipped** · default `dart test test/acceptance -x stretch` → **7 passed / 25 skipped** (all ACs pending-skipped) · red baseline `PIGMENT_KM_RUN_PENDING=true dart test test/acceptance -x stretch` → **+8 / −24** (AC-6 + the two harness guards green; 24 ACs fail for-cause) · run-pending `-t stretch` → **+0 / −2** (AC-26/27 on their G-7 scope precondition).

**Red-baseline summary (run-pending):** 26 of 27 tests fail for the right reason — on a `Then`, on a `When` that throws the behaviour's documented `UnimplementedError` naming its phase, or on a `Given`/scope precondition naming its owning phase/gate. **AC-6 is green at baseline** (the DATA-1 shell loader already satisfies the artifact contract). Per-AC rows: the *Red baseline* table below.

**The packet — one pending test per AC (Given → When → Then / Rejects):**

| AC | Test (owner · grade) | Given → When → Then · Rejects |
|---|---|---|
| AC-1 | TestAC01_SpectrumToColour (COLOR-2 · A) | Given perfect-diffuser spectrum (len 31) w/ published D65-white XYZ/sRGB → When `spectrumToColour` (D65, CIE-1931) → Then ΔE00(result, published) ≤ 1 via the harness's independent CIEDE2000 + Y≈1 + sRGB white · Rejects wrong normalization / dropped illuminant weighting |
| AC-2 | TestAC02_GamutMap (COLOR-3 · A) | Given a colour with channels outside [0,1] (asserted OOG) → When `gamutMap` → Then sRGB in [0,1] + L & hue preserved + chroma reduced + result ≠ per-channel clamp · Rejects the hard clip |
| AC-3 | TestAC03_KmRoundTrip (KM-2 · A) | Given a finite K/S>0 vector → When `kmReflectance` then `kmFunction` → Then R∞∈[0,1] every bin (the assertion that rejects the +√ branch — roots are reciprocals so round-trip alone can't) + K/S=0→R=1 + K/S round-trips to 1e-5 · Rejects the branch-sign swap |
| AC-4 | TestAC04_Saunderson (KM-3 · A) | Given internal R + each medium's (k1,k2), media constants asserted distinct → When internal→measured→internal (acrylic) → Then recovered R to 1e-5 + control: same input gives different measured per medium, measured≠input · Rejects no-op / one global k1,k2 |
| AC-5 | TestAC05_TwoConstantMix (**KM-4 ⚠ colour Then needs FORWARD-2** · A) | Given two paints, Σv=1 → When `forward` mixes → Then self-mix(any ratio)=pure colour + order-independent + controls (mix≠each pure; 25/75≠75/25≠50/50) · Rejects volume-ignoring / order-dependent mix |
| AC-6 | TestAC06_Artifact (DATA-3 · A · **green at baseline**) | Given a medium's loaded table (non-empty) → When read each paint → Then K,S len 31 + pigmentIndex + opacity∈[0,1] + provenance + sourceRef + medium tag, and `load == decode(shipped asset)` · Rejects a loader dropping K/S or leaving provenance null |
| AC-7 | TestAC07_RoundTripFidelity (DATA-5 · A data-limited, G-3) | Given real Golden/RIT acrylic + published colours (precondition fails at baseline naming G-3/DATA-5) → When render K,S→R∞→colour → Then ΔE00(rendered, published) ≤ 0.5 every paint · Rejects wrong k1,k2/grid · augment: DATA-5 flips fixture to real data (no rewrite) |
| AC-8 | TestAC08_Resample (DATA-2 · A) | Given a linear ramp on the native 380–730@10 grid (len 36) → When `resampleOntoCanonical` → Then len 31 on 400–700@10 + exact value at every canonical bin + endpoints · Rejects nearest-bin/index-misplaced copy |
| AC-9 | TestAC09_OilFit (DATA-6 · **B pending DATA-6**, G-4) | Given MPI oil pure+mixtures w/ ratios & disjoint split (precondition fails at baseline naming G-4) → When per-λ NNLS on train → Then held-out ΔE00 ≤ 5 + coeffs ≥ 0 + split disjoint · Rejects negative K/S or training on held-out · augment: DATA-6 **ADDs** the whole Then (not just flip `isReal`) |
| AC-10 | TestAC10_MasstoneTint (DATA-4 · A) | Given masstone + 3 tints built from a known (K,S) via the test's **own independent** 2-constant KM ref (tints≥2, fractions∈(0,1)) → When `deriveKsFromMasstoneTint` → Then derived K,S re-predict every tint + the masstone to 1e-3 · Rejects masstone-alone (wrong S scale) / ignoring white K_w,S_w |
| AC-11 | TestAC11_Attribution (DATA-7 · A data-limited, G-3) | Given the built tree → When inspect → Then LICENSE=MIT + NOTICE has CC BY 4.0 + Asadi/Babaei/Seidel + "changes" + RIT + every synthetic paint `estimated`/`synthetic:`; real-source `Calculated` Then behind `isReal` precondition naming DATA-7 · Rejects missing NOTICE / unattributed data · augment: DATA-7 finalizes Golden/RIT wording + flips provenance |
| AC-12 | TestAC12_ForwardFidelity (FORWARD-3 · A data-limited, G-3/G-4) | Given a measured mixture w/ published colour (precondition fails naming FORWARD-3), parts Σ1 → When `forward` → Then ΔE00(prediction, measured) ≤ 5 · Rejects single-constant (ignores S) · augment: FORWARD-3 populates the real measured mixtures (no rewrite) |
| AC-13 | TestAC13_Desaturation (FORWARD-4 · A) | Given two chromatic paints of differing hue (c>0.04, Δhue>20°) → When mix equal volume, compare to naive linear-RGB midpoint → Then chroma(KM mix) < chroma(RGB blend) · Rejects an RGB-space blend (the natural-colour check) |
| AC-14 | TestAC14_Normalize (FORWARD-2 · A) | Given parts not summing to 1 (2:1, sum≈3≠1) → When `forward` → Then equals forward of the Σ1-normalized ratio to 1e-6 + control 6:3 matches, 1:2 differs · Rejects raw (unnormalized) weights / collapse-to-constant |
| AC-15 | TestAC15_RankedPreferFewer (SOLVER-3 · A) | Given target + palette≥2 → When `inverse` (topK=5) → Then ≤topK, ≥2 candidates, best-first by ΔE00 (non-vacuous), parts Σ1 ∈ palette; on a tie fewer-paint first · Rejects unstable/unsorted/single-recipe/dataset-leaky solver · augment: SOLVER-3 constructs a guaranteed 2-vs-3-paint tie |
| AC-16 | TestAC16_PaletteOnly (SOLVER-2 · A) | Given reddish target + palette that excludes the red (asserted absent) → When `inverse` → Then every paint in every recipe ∈ palette · Rejects a solver reaching into the full dataset |
| AC-17 | TestAC17_InGamut (SOLVER-6 · A, validation ↔ G-6) | Given an in-gamut target (pale cool grey) → When `inverse`, take best → Then best ΔE00 ≤ 5 (gamutThreshold) + not flagged OOG · Rejects stopping early above 5 · the honesty pair of AC-18; SOLVER-6 confirms the reachable target, G-6 adds held-out validation |
| AC-18 | TestAC18_OutOfGamut (SOLVER-4 · A) | Given `oogColour` (pure green, c>0.2, no green primary → unreachable) → When `inverse`, take best → Then flagged `outOfGamut` + honest ΔE00 > 5, never a match · Rejects a nearest-mix returned unflagged |
| AC-19 | TestAC19_CrossMedium (SOLVER-5 · A) | Given a palette with BOTH acrylic+oil paints (asserted present) → When `inverse` → Then every recipe is single-medium matching its declared medium · Rejects a cross-medium mix · ⚠ SOLVER-5 should add a constructed cross-medium-tempting control target |
| AC-20 | TestAC20_Performance (SOLVER-7 · A, exclusive lane) | Given a ~15-paint single-medium palette (asserted size 15) → When `inverse` top-3, timed → Then ≤3 recipes within ≤ 2 s · Rejects an exponential search |
| AC-21 | TestAC21_NoNeon (TUNE-3 · A data-limited, G-3) | Given the curated palette (synthetic until the real Zorn-style acrylic lands) → When predict all single+pair mixes / solve a muted & a neon target → Then no mix exceeds a provisional chroma ceiling (0.25) + muted ≤ 5 + neon flagged OOG · Rejects neon-admitting palette · augment: TUNE-3 ships the real palette **and hardens the ceiling** (not just swap data) |
| AC-22 | TestAC22_ChromaPenalty (TUNE-2 · A) | Given plain (chromaPenalty off) ranking asserted ΔE00-monotonic → When re-rank with penalty on → Then on every ΔE00 tie with a chroma gap the lower-chroma recipe ranks first; `expect(sawTie, isTrue)` · Rejects a penalty that dominates ΔE00 or has no effect · augment: TUNE-2 constructs the guaranteed equal-ΔE00 differing-chroma tie, with the un-pend |
| AC-23 | TestAC23_WetDry (**TUNE-4 ⚠ interface decision for G-2** · A) | Given a target solved acrylic, read wet & dry (toggle on `MixOptions.wet` — observed via `inverse` because `forward()` takes no options) → When solve wet then dry → Then parts unchanged + dry differs from wet by the documented offset (darker, hue-shifted) · Rejects no-op or re-solve-that-changes-parts |
| AC-24 | TestAC24_Provenance (PROD-2 · A) | Given a palette tagged `Calculated` (from measured data) and a single user tube tagged `Measured` → When `inverse` each, read provenance → Then measured-data recipe=Calculated, user-tube recipe=Measured · Rejects claiming Measured from the dataset or Estimated from measured data (SI D-8) |
| AC-25 | TestAC25_ABEngines (PROD-3 · A) | Given both engines as `MixingEngine` (asserted) → When drive each via the identical `inverse(target,palette,opts)` call on the same swatch set → Then both return recipes w/ no caller change + each reports a finite non-negative ΔE00 per swatch · Rejects a baseline wired outside the interface |
| AC-26 @stretch | TestAC26_Glazing (STRETCH-2 · **B pending**, G-7) | **Scope-gated behind open G-7** — the finite-thickness layering API is deliberately NOT frozen; body asserts `_stretchScopeApproved` only. Documented scenario for STRETCH-2: Given a mix glazed at finite X over ground Rg → When compute layered R → Then follows §3.4, R→opaque as X→∞ · Rejects reusing the opaque form |
| AC-27 @stretch | TestAC27_Metamerism (STRETCH-3 · **B pending**, G-7) | **Scope-gated behind open G-7** — the multi-illuminant API is NOT frozen (the `illuminants` d65+warm fixture is staged); body asserts scope only. Documented scenario for STRETCH-3: Given two recipes equal under D65 → When evaluate under D65 + warm studio → Then the degrading one gets the higher metamerism index + fragility warning · Rejects a single-illuminant index |

**Scheduled augmentations** (9 — full in the *Test augmentations* table below): TestAC07→DATA-5, TestAC09→DATA-6 (ADD the Then), TestAC11→DATA-7, TestAC12→FORWARD-3, TestAC15→SOLVER-3 (constructed tie), TestAC21→TUNE-3 (real palette + harden ceiling), TestAC22→TUNE-2 (constructed tie), TestAC26→STRETCH-2, TestAC27→STRETCH-3. Each closed by its owning behaviour phase; the AC's coverage is ✅ only once its test is un-pended, green, and its augmentation row is closed.

**What the reviewer should look at first:**
1. **AC-23 wet/dry interface — the one genuine design decision for G-2.** `forward()` takes no options, so the test reads wet/dry through `inverse(MixOptions.wet)` + `Recipe.colour`. G-2 should resolve whether wet/dry stays a **post-prediction state transform** or `forward` gains an options parameter; TUNE-4 implements whichever is chosen.
2. **AC-5 owner mismatch.** AC-5's colour-level Then goes through `CustomKmEngine.forward` (FORWARD-2), but its pending owner is KM-4. Either move AC-5's un-pend to FORWARD-2 or expose a public K,S-mixing surface for a KM-4-level assertion. Flagged, not rewired.
3. **AC-6 is green at baseline** — kept pending→DATA-3 rather than cascade-editing the ITEST-1 bijection guard. The reviewer may un-pend it now; its asset path `assets/pigments/synthetic_<medium>.json` must survive any DATA-3/DATA-5 rename.
4. **The 4 data-limited A's (AC-7/11/12/21)** and **3 B-pending (AC-9, AC-26, AC-27)** — confirm the gate/data deferrals are acceptable (G-3/G-4 fidelity data; G-7 stretch scope). AC-9/AC-26/AC-27 are the only three graded below A, all for an open gate, none in-phase-fixable.
5. **Augmentation obligations that are more than data swaps:** AC-9 (DATA-6 must ADD the full held-out-fit Then), AC-15/AC-22 (constructed equal-ΔE00 ties, built *with* the un-pend), AC-21 (TUNE-3 must harden the real chroma ceiling, not just swap palette).
6. **Backend stub signatures are frozen** by ITEST-2/3 (`spectrumToColour`, `gamutMap`, `kmReflectance`/`kmFunction`, `configForMedium`/`saundersonToMeasured`/`saundersonToInternal`, `resampleOntoCanonical`, `deriveKsFromMasstoneTint`) — behaviour phases fill the bodies; change a signature only with a recorded reason.

**Decision to record** (one of):
- `/feature-next-phase --gate pigment-km-engine G-2 approved`
- `/feature-next-phase --gate pigment-km-engine G-2 "changes: <items>"` — each item becomes an ITEST change phase before the behaviour stage, then a fresh review.

**Verification (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"` first. `dart analyze` · `dart test` · default/red-baseline acceptance as above · `dart test -x stretch` excludes AC-26/27.

**Checkpoint / Handoff.** On **G-2 approved**, the behaviour stage opens: module heads **COLOR-2 ∥ KM-2 ∥ DATA-2** are startable (disjoint files); un-pend = delete the AC's row in `pending.dart`; honour every augmentation row above. On **changes requested**, each item is an ITEST change phase, then ITEST-6 re-review. No code/tests changed this session — the suite is exactly as ITEST-4 left it.

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
| AC-19 | TestAC19_CrossMedium | fail | When — `UnimplementedError: CustomKmEngine.inverse — SOLVER phases` | SOLVER-5 | A |
| AC-20 | TestAC20_Performance | fail | When — `UnimplementedError: CustomKmEngine.inverse — SOLVER phases` | SOLVER-7 | A |
| AC-21 | TestAC21_NoNeon | fail | When — `UnimplementedError: CustomKmEngine.forward — FORWARD phases` | TUNE-3 | A (data-limited) |
| AC-22 | TestAC22_ChromaPenalty | fail | When — `UnimplementedError: CustomKmEngine.inverse — SOLVER phases` | TUNE-2 | A |
| AC-23 | TestAC23_WetDry | fail | When — `UnimplementedError: CustomKmEngine.inverse — SOLVER phases` | TUNE-4 | A |
| AC-24 | TestAC24_Provenance | fail | When — `UnimplementedError: CustomKmEngine.inverse — SOLVER phases` | PROD-2 | A |
| AC-25 | TestAC25_ABEngines | fail | When — `UnimplementedError: CustomKmEngine.inverse — SOLVER phases` | PROD-3 | A |
| AC-26 | TestAC26_Glazing (@stretch) | fail | Given precondition — S6 glazing scope gated behind G-7 (`_stretchScopeApproved` false) | STRETCH-2 | B pending STRETCH-2 |
| AC-27 | TestAC27_Metamerism (@stretch) | fail | Given precondition — S6 metamerism scope gated behind G-7 (`_stretchScopeApproved` false) | STRETCH-3 | B pending STRETCH-3 |

## Test augmentations  <!-- pre-seeded; confirmed by AC-test phases; closed by behavior phases -->

| AC test | Limited because | Augmented by | Add | Status |
|---|---|---|---|---|
| TestAC07 | real Golden/RIT data + published colours not yet on disk (G-3); live Then is behind a precondition that fails at baseline | DATA-5 | populate the `acrylicPublished` fixture with the shipped acrylic table + published colours (`isReal=true`); the existing Then (ΔE00 ≤ 0.5 for every paint) then runs — no test rewrite | ⬜ Open |
| TestAC09 | MPI oil data + fit API not yet on disk (G-4/G-5); **precondition-only at baseline** — graded *B pending DATA-6* | DATA-6 | **ADD the executable Then** (not merely flip `isReal`): per-λ NNLS fit on the train split, predict held-out mixtures ΔE00 ≤ 5 each, assert every fit coeff ≥ 0 at every λ, assert the train/held-out split is disjoint | ⬜ Open |
| TestAC11 | Golden/RIT attribution wording pending the permission text (G-3); real-source provenance Then (measured→Calculated) behind the `isReal` precondition | DATA-7 | finalize + assert the agreed Golden/RIT NOTICE wording (tighten "states changes" to the exact text); flip `acrylicPublishedPlaceholder.isReal`; tag the real acrylic paints `Provenance.calculated` | ⬜ Open |
| TestAC12 | measured mixtures not yet on disk (G-3/G-4); `measuredMixturesPlaceholder` is a placeholder — precondition-gated at baseline | FORWARD-3 | populate `measuredMixturesPlaceholder` (isReal=true, ≥1 real multi-paint mixture + published colour); the written ΔE00 ≤ 5 loop then runs — no test rewrite | ⬜ Open |
| TestAC15 | prefer-fewer-on-tie reject needs an equal-ΔE00 2-vs-3-paint tie only the built solver can produce; at baseline the in-test tie loop fires only on a natural tie | SOLVER-3 | add a constructed guaranteed equal-ΔE00 2-vs-3-paint tie asserting the 2-paint recipe ranks first | ✅ Closed (SOLVER-3) — 6 identical-reflectance twins → 56 bit-equal-ΔE00 candidates (above Dart's 32-elem stable-sort threshold → unstable quicksort), so the non-decreasing paint-count ranking needs the explicit prefer-fewer key; verified it fails the pre-phase ΔE00-only sort |
| TestAC21 | real curated palette needs the acrylic data (G-3); asserts the neon-impossible property on the synthetic palette against a provisional in-test chroma ceiling (0.25), not gated behind an `isReal` precondition | TUNE-3 | switch to the shipped Zorn-style acrylic palette **and** confirm/tune the real naturalistic chroma ceiling (harden the bound, not merely swap data) | ⬜ Open |
| TestAC22 | the chroma-penalty tie-break only fires on an equal-ΔE00 differing-chroma pair the synthetic solve won't deterministically produce; `expect(sawTie, isTrue)` requires one | TUNE-2 | construct a guaranteed equal-ΔE00 2-vs-3-paint tie (differing chroma) asserting the lower-chroma recipe ranks first, built together with the un-pend | ⬜ Open |
| TestAC26 (@stretch) | finite-thickness glazing is an optional S6 scenario gated behind the open G-7; its layering API is deliberately not frozen before scope approval — body asserts the G-7 scope precondition only | STRETCH-2 | once G-7 approves, freeze the layering API and replace the placeholder body with the documented Given/When/Then (incl. X→∞ → opaque-form control) | ⬜ Open (G-7) |
| TestAC27 (@stretch) | metamerism index is an optional S6 scenario gated behind the open G-7; its multi-illuminant API is deliberately not frozen before scope approval — body asserts the G-7 scope precondition only (the `illuminants` d65+warm fixture is staged) | STRETCH-3 | once G-7 approves, freeze the metamerism-index API and replace the placeholder body with the documented Given/When/Then (incl. the single-illuminant reject) | ⬜ Open (G-7) |
