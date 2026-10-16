# Module ITEST — acceptance integration suite

**Status:** 🔄 In progress (ITEST-1 ✅)
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `test/acceptance/*` (harness, fixtures, pending gate, one test per AC), `test/acceptance/fixtures/*`
**Depends on:** CORE-2, DATA-1 (shells) · **Blocks:** every behavior phase (via G-2)

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 1 (ITEST-1) | acceptance-tests | — (harness) | ✅ Done | 5.53M | 12m 21s |
| 2 (ITEST-2) | acceptance-tests | AC-1..9 | ⬜ Todo | | |
| 3 (ITEST-3) | acceptance-tests | AC-10..18 | ⬜ Todo | | |
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

### Result · Checkpoint  <!-- filled on completion -->

## Phase 3 — ITEST-3: AC-10..18 (pending) + red baseline
- **Kind:** acceptance-tests · **Target AC:** AC-10..AC-18 · **Depends on:** ITEST-1 · **Blocks:** ITEST-5 · ∥ ITEST-2/4
- **Tasks/Exit:** as ITEST-2 for `TestAC10..TestAC18`.

### Result · Checkpoint  <!-- filled on completion -->

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
| AC-1 | TestAC01_SpectrumToColour | (pending) | — | COLOR-2 | — |
| … | (filled ITEST-2/3/4) | | | | |

## Test augmentations  <!-- pre-seeded; confirmed by AC-test phases; closed by behavior phases -->

| AC test | Limited because | Augmented by | Add | Status |
|---|---|---|---|---|
| TestAC07 | real Golden/RIT data not yet on disk (G-3); asserts round-trip on the synthetic fixture | DATA-5 | switch fixture→shipped acrylic table; ΔE00 ≤ 0.5 for every real paint | ⬜ Open |
| TestAC09 | MPI oil data not yet on disk (G-4); asserts the fit on synthetic mixtures | DATA-6 | switch to MPI held-out mixtures; ΔE00 ≤ 5; coeffs ≥ 0 | ⬜ Open |
| TestAC11 | Golden/RIT attribution wording pending the permission text (G-3) | DATA-7 | assert the finalized Golden/RIT NOTICE block | ⬜ Open |
| TestAC12 | measured mixtures not yet on disk (G-3/G-4); asserts forward on synthetic mixtures | FORWARD-3 | switch to measured mixtures; ΔE00 ≤ 5 | ⬜ Open |
| TestAC21 | real curated palette needs the acrylic data (G-3); asserts the neon-impossible property on the synthetic palette | TUNE-3 | switch to the shipped Zorn-style acrylic palette | ⬜ Open |
