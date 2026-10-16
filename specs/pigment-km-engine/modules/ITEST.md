# Module ITEST — acceptance integration suite

**Status:** Not started
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `test/acceptance/*` (harness, fixtures, pending gate, one test per AC), `test/acceptance/fixtures/*`
**Depends on:** CORE-2, DATA-1 (shells) · **Blocks:** every behavior phase (via G-2)

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 1 (ITEST-1) | acceptance-tests | — (harness) | ⬜ Todo | | |
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

### Result · Checkpoint  <!-- filled on completion -->

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
