# Module DATA — datasets, ingestion, build artifact, attribution

**Status:** In progress — DATA-1 ✅; DATA-8 ✅ (fixture hue-faithful, G-8); DATA-2 ✅ (AC-8 resampler); DATA-3 ✅ (AC-6 load decodes the shipped asset, 2026-10-18 — 13 A re-grade, 0 fixes). Next DATA-4 (AC-10 masstone–tint); DATA-5/6/7 gated on G-3/G-4
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/data/pigment_table.dart` (loader), `lib/src/data/artifact_format.dart`, `lib/src/data/resample.dart`, `lib/src/data/masstone_tint.dart`, `lib/src/data/nnls_fit.dart`, `lib/src/data/synthetic_fixture.dart`, `assets/pigments/*` (shipped build artifacts, medium-tagged), `NOTICE`/`ATTRIBUTION.md`, `tool/ingest/*` (offline ingest scripts, not shipped at runtime)
**Depends on:** CORE, COLOR, KM · **Blocks:** FORWARD-3, SOLVER (real palette), TUNE-3; **DATA-8 blocks SOLVER-6** (the fixture must render faithful hues before AC-17's in-gamut target is reachable)

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 1 (DATA-1) | shell | — | ✅ Done | 4.16M | 8m39s |
| 2 (DATA-2) | behavior | AC-8 | ✅ Done | 5.22M | 11m 07s |
| 3 (DATA-3) | behavior | AC-6 | ✅ Done | 6.06M | 11m 08s |
| 4 (DATA-4) | behavior | AC-10 | ⬜ Todo | | |
| 5 (DATA-5) | behavior | AC-7 | ⬜ Todo (G-3) | | |
| 6 (DATA-6) | behavior | AC-9 | ⬜ Todo (G-4) | | |
| 7 (DATA-7) | behavior | AC-11 | ⬜ Todo (G-3) | | |
| 8 (DATA-8) | enabler | — | ✅ Done | — | — |

## Interface reconciliation

Build-time ingest (design §4, SI D6) produces a compact medium-tagged artifact of K,S vectors on the canonical grid; the runtime only *loads* it (no recompute). Acrylic ships turnkey K,S (design §4.1); oil's K,S are fit from mixtures (§4.2). Ingest lives in `tool/ingest/` (offline), the artifact under `assets/`. The synthetic fixture (D-7) ships a tiny hand-authored table so the suite runs before the real data lands.

## Open gates

- **G-3** (dependency): the Golden/RIT acrylic data + its fields/k1,k2/attribution wording → blocks DATA-5, DATA-7. **Permission letter obtained 2026-10-17** (owner holds written permission from Berns/RIT) → redistribution cleared; DATA-7 must honour the letter's required attribution wording. Still open: grid/units/`k1,k2` from the dataset README, and whether IS&T paper-copyright wording is also required.
- **G-4** (dependency): the MPI oil dataset + mixtures → blocks DATA-6.
- **G-5** (decision): per-medium k1,k2 + S-normalization (folds into G-3/G-4).
- **G-8** (decision, ✅ resolved 2026-10-17 — Matt Quirk): the synthetic fixture rendered chromatic paints as the **complement** of their names — `_chroma` peaked each paint's absorption K at its *named* hue's bin, so "phthalo_blue" (peakBin 4 ≈440 nm) absorbs blue and renders orange/tan, "naphthol_red" (peakBin 22 ≈620 nm) renders cyan-ish (oil ultramarine/yellow_ochre likewise). Decision: **fix the fixture to be hue-faithful (DATA-8)**, not retarget AC-17. Blocks DATA-8, SOLVER-6.

## Phase 1 — DATA-1 shell: artifact format + loader + fixture

- **Kind:** shell · **Target AC:** —
- **Depends on:** CORE-2 · **Blocks:** ITEST-1, all DATA behavior
- **Files:** `artifact_format.dart`, `pigment_table.dart`, `assets/pigments/synthetic.*`, `NOTICE`/`ATTRIBUTION.md` scaffold
- **Tasks:** define the serialized artifact schema (medium, per-paint id/name/pigmentIndex/K/S/opacity/provenance/sourceRef); `PigmentTable.load(Medium)` reading it; ship the synthetic fixture; scaffold the NOTICE with the MPI CC BY 4.0 block (design §13.4) and a Golden/RIT placeholder.
- **Exit criteria:** analyze clean; 100% touched; `load(acrylic)`/`load(oil)` return the fixture; the suite can observe pigment fields; behavior unchanged.

### Result

Landed the data stage's shell (behaviour unchanged):
- `lib/src/data/artifact_format.dart` — `PigmentArtifact` (version, medium, pigments) + `PigmentArtifactCodec.encode/decode`. On-disk form is stable indented JSON `{version, medium, grid{start,end,step,bins}, paints[{id,name,pigmentIndex,opacity,provenance,sourceRef,k[31],s[31]}]}`. `decode` validates version, medium, provenance, the embedded grid (rejects any non-canonical grid — resample is an ingest step, AC-8, never a load one) and every spectrum's length, all as `FormatException`.
- `lib/src/data/pigment_table.dart` — `PigmentTable.load(Medium)` (the data-stage read endpoint), `.fromArtifact`, `.byId`; `pigments` is unmodifiable.
- `lib/src/data/synthetic_fixture.dart` — the D-7 placeholder: 3 paints per medium, honestly tagged `Provenance.estimated` with `sourceRef` `synthetic:…` (never measured/calculated).
- `assets/pigments/synthetic_{acrylic,oil}.json` — the shipped build artifacts, generated from the builder via `encode`; a parity test asserts file == `encode(builder)` so they cannot drift.
- `ATTRIBUTION.md` — companion to the existing NOTICE (which already carries the MPI CC BY 4.0 block + Golden/RIT permission block from CORE-1); maps each source → provenance tier; real acrylic wording pending G-3/DATA-7, oil pending G-4/DATA-6.
- Exported the two public data files from `lib/pigment_km.dart` (`SyntheticFixture` stays internal under `src/`).

Verify (green): `dart analyze` clean · `dart test` **54/54** (+26; 28 pre-existing unchanged) · coverage gate **PASS 100% lines touched** (artifact_format 87/87, pigment_table 9/9, synthetic_fixture 32/32; entry has no executable lines). No acceptance suite yet (ITEST-1 creates it). Fix passes: 1/3 (first run: 3 interpolation-brace lints + 1 test — `decode` wrong-length threw `ArgumentError` via `checkLength`; switched `_spectrum` to raise `FormatException` itself per the decode contract). Tokens/Time: see dashboard.

### Checkpoint / Handoff

- **Frozen interfaces (build against these):** `PigmentArtifactCodec.{currentVersion=1, encode, decode}`; `PigmentArtifact{version, medium, pigments}`; `PigmentTable.{load(Medium), fromArtifact(artifact), medium, pigments (unmodifiable), byId(id)}`. The JSON schema above is the shipped artifact contract. `Provenance.estimated` is the only tier the synthetic data uses.
- **Shell gap (deliberate):** `load` builds the synthetic table **in memory**; the shipped `assets/pigments/synthetic_*.json` are generated from the same builder and drift-guarded by test. DATA-3 (AC-6 full load path) switches `load` to *decode the shipped asset*, making the file the single source; DATA-5/DATA-6 ingest regenerate the real acrylic/oil artifacts.
- **Verification (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"` first. `dart analyze` · `dart test` · `bash tool/coverage_gate.sh <BASE>` (line-only, documented). To regenerate an asset after a fixture change: a tiny `dart run` script that calls `PigmentArtifactCodec.encode(SyntheticFixture.artifact(m))` and writes `assets/pigments/synthetic_<m>.json` + a trailing newline (the parity test pins the exact bytes).
- **Known gaps:** none new. Line-coverage-only gate (CORE-1 deviation) still applies.
- **Next:** CORE + DATA shells done → **ITEST-1** (acceptance harness over the wired shells; needs both). Then ITEST-2∥3∥4 (one pending test per AC + red baseline) → ITEST-5 test review (**G-2**) before any behaviour. DATA behaviour (DATA-2 resample … DATA-7 attribution) unblocks after G-2; DATA-5/6/7 also need the dataset gates G-3/G-4/G-5.

## Phase 2 — DATA-2: resample onto the canonical grid (AC-8)

- **Kind:** behavior · **Target AC:** AC-8 (full)
- **Depends on:** DATA-1 · **Blocks:** DATA-3
- **Files:** `resample.dart`
- **Tasks:** linear (or documented) resample from a native grid (380–730 / 400–700) onto 400–700@10; endpoint handling; use in ingest.
- **Exit criteria:** analyze clean; 100% touched; length 31; interior + endpoint interpolation correct.
- **Acceptance gate:** un-pend AC-8; `TestAC08_Resample` green.

### Result · Checkpoint  <!-- DATA-2 ✅ 2026-10-17 -->

- **Landed:** `resampleOntoCanonical(List<double> wavelengthsNm, List<double> values)`
  in `lib/src/data/resample.dart` (stub → real). Linear interpolation onto the
  canonical 400–700@10 grid (31 bins); strictly-ascending native wavelengths,
  ≥ 2 samples, equal lengths validated (`ArgumentError`); canonical bins outside
  the native range held flat at the nearest endpoint (documented constant
  extrapolation — never needed by the in-scope grids but keeps a short grid
  well-defined). A single advancing cursor over the native grid → O(n+m).
- **Un-pend:** AC-8 row deleted from `test/acceptance/harness/pending.dart`, added
  to `unpendedACs` in `test/acceptance/pending_gate_test.dart`; the
  `resampleOntoCanonical` `throwsUnimplementedError` row dropped from
  `test/backends_stub_test.dart` (now implemented). New unit suite
  `test/resample_test.dart` (interior interpolation on an offset grid, exact-hit
  copy, flat clamp both ends, all three validation throws).
- **Gates:** `dart analyze` clean (touched files); default suite green
  (AC-8 live and passing); run-pending red baseline unchanged except AC-8 now
  green (12 failures = the still-pending later-phase ACs); coverage **25/25 lines**
  on `resample.dart` (gate PASS). No augmentations assigned/enabled (resample is
  a standalone ingest helper no other AC test depends on).
- **Grade gate:** fresh adversarial subagent re-graded all 12 un-pended AC tests
  → **12 A, 0 B, 0 regressions**. AC-8 re-confirmed A (rejects the index-misplaced
  copy; the fractional-interpolation branch, unexercised by the 10 nm-aligned AC
  fixture, is discriminated by `test/resample_test.dart`). Band appended to
  `behavior-test-completeness-pigment-km-engine.md`.
- **Fix passes:** 0/3 (passed first full run).

**Checkpoint / Handoff.** Verification (repo root, `export PATH="$HOME/development/flutter/bin:$PATH"`):
`dart analyze lib test` · `dart test` (default, green) ·
`PIGMENT_KM_RUN_PENDING=true dart test test/acceptance` (red baseline) ·
`bash tool/coverage_gate.sh <BASE>`. **Frozen interface:**
`Spectrum resampleOntoCanonical(List<double> wavelengthsNm, List<double> values)`
— ascending native grid, linear interp onto the canonical grid, endpoint clamp.
**Next DATA-3** (AC-6 full artifact load path, `pigment_table.dart`/`artifact_format.dart`):
make `load` *decode the shipped asset* and use `resampleOntoCanonical` for any
native-grid ingest; DATA-3 blocks on nothing new (G-2 cleared).

## Phase 3 — DATA-3: artifact fields loaded (AC-6)

- **Kind:** behavior · **Target AC:** AC-6 (full)
- **Depends on:** DATA-2 · **Blocks:** DATA-4
- **Files:** `pigment_table.dart`, `artifact_format.dart`
- **Tasks:** full load path populating every field; medium tagging; provenance + sourceRef from the artifact.
- **Exit criteria:** analyze clean; 100% touched; every paint exposes all fields; medium matches.
- **Acceptance gate:** un-pend AC-6; `TestAC06_Artifact` green.

### Result · Checkpoint  <!-- DATA-3 ✅ 2026-10-18 -->

- **Landed:** `PigmentTable.load(medium)` now **decodes the shipped asset** — it
  reads `File(assetPathFor(medium)).readAsStringSync()` and
  `PigmentArtifactCodec.decode`s it, so the file (`assets/pigments/synthetic_<medium>.json`)
  is the single source of truth; nothing is rebuilt in memory (`load` no longer
  imports `SyntheticFixture`). The decode throws `FileSystemException`/`FormatException`
  on a missing or malformed artifact (a bad build fails loudly, never silently).
  New public static `PigmentTable.assetPathFor(Medium)` centralises the path so
  DATA-5/DATA-6 can point it at the real `<medium>.json` artifacts. **Memoised**
  per medium (`_cache`): `load` is on the engine forward path
  (`custom_km_engine._resolve` per paint-id), so the artifact is read+decoded once
  per medium per process, not on every call — no perf regression (AC-20).
- **Load does not resample:** `decode` already rejects a non-canonical grid (AC-8
  resample is an *ingest* step, never a load one), so DATA-3's load path leaves
  `resampleOntoCanonical` to DATA-5/DATA-6 ingest. `artifact_format.dart`
  unchanged (its `decode` already populates every field).
- **Un-pend:** AC-6 row deleted from `test/acceptance/harness/pending.dart`, added
  to `unpendedACs` in `test/acceptance/pending_gate_test.dart`. No
  `throwsUnimplementedError` stub to drop (load was already implemented at the
  shell). No augmentation assigned or newly enabled (AC-6 has no augmentation row).
- **Unit tests** (`test/data_test.dart`): load == `decode(File(assetPathFor(m)))`
  for both media (ties `load` to the shipped file); `assetPathFor` returns the
  per-medium path; memoisation (`identical(load(m), load(m))`, distinct media
  distinct tables). The existing field/round-trip/parity groups unchanged.
- **Gates:** `dart analyze lib test` clean; default suite green (148 pass / 14
  pending-skipped); run-pending red baseline correct — AC-6 now green, the 12
  still-unbuilt later-phase ACs fail for cause (AC-17/AC-20 pending-but-green as
  since DATA-8); coverage **12/12 lines** on the only touched lib file
  `pigment_table.dart` (gate PASS).
- **Grade gate:** fresh adversarial subagent re-graded all 13 un-pended AC tests
  → **13 A, 0 downgrades**; AC-6 moves from *green-at-baseline* to a genuinely-live
  load-from-asset test and stays A. No regression (file-sourced palette is
  byte-identical to the prior in-memory fixture — parity test enforces it). Band
  appended to `behavior-test-completeness-pigment-km-engine.md`.
- **Fix passes:** 0/3 (passed first full run).

**Checkpoint / Handoff.** Verification (repo root, `export PATH="$HOME/development/flutter/bin:$PATH"`):
`dart analyze lib test` · `dart test` (default, green) ·
`PIGMENT_KM_RUN_PENDING=true dart test test/acceptance` (red baseline) ·
`bash tool/coverage_gate.sh <BASE>`. **Frozen interface:**
`PigmentTable.{load(Medium) [decodes assetPathFor(medium), memoised], assetPathFor(Medium), fromArtifact, medium, pigments, byId}`.
**For DATA-5/DATA-6:** the real ingest writes `assets/pigments/<medium>.json` and
points `assetPathFor` at it (the synthetic path must survive or be updated — the
AC-6 test and the parity test both key off `assetPathFor`/`synthetic_<medium>.json`).
**Known gap (unchanged):** `load` reads the asset by a path relative to the
package root (the cwd every consumer and test already assumes); a future
*published*-package consumer would need package-URI / asset-bundle resolution —
out of scope while `publish_to: none`. `tool/ingest/` stays untracked DATA-5/6
material (not staged).

## Phase 4 — DATA-4: masstone–tint derivation (AC-10)

- **Kind:** behavior · **Target AC:** AC-10 (full)
- **Depends on:** DATA-3, KM-3 · **Blocks:** DATA-5
- **Files:** `masstone_tint.dart`
- **Tasks:** derive K,S per wavelength from masstone + tint series by least squares across tints (design §4.4), white K_w,S_w known, S_w≡1; the hook for user-measured tubes.
- **Exit criteria:** analyze clean; 100% touched; derived K,S reproduce each tint's R within tol.
- **Acceptance gate:** un-pend AC-10; `TestAC10_MasstoneTint` green.

### Result · Checkpoint  <!-- filled on completion -->

## Phase 5 — DATA-5: acrylic round-trip fidelity (AC-7) — needs G-3

- **Kind:** behavior · **Target AC:** AC-7 (full)
- **Depends on:** DATA-4, KM-3, COLOR-2 · **Blocks:** DATA-7
- **Files:** `tool/ingest/acrylic.dart`, `assets/pigments/acrylic.*`
- **Tasks:** ingest the real Golden/RIT K,S (G-3) onto the canonical grid with the confirmed k1,k2 (G-5); ship the artifact; prove every paint round-trips to its published colour ≤ 0.5 ΔE00.
- **Exit criteria:** analyze clean; 100% touched; round-trip gate met for all acrylic paints.
- **Acceptance gate:** un-pend AC-7; `TestAC07_RoundTripFidelity` green against real acrylic data; **augment** AC-7 from the synthetic placeholder to the shipped table.

### Result · Checkpoint  <!-- filled on completion -->

## Phase 6 — DATA-6: oil K,S fit from mixtures (AC-9) — needs G-4

- **Kind:** behavior · **Target AC:** AC-9 (full)
- **Depends on:** DATA-4 · **Blocks:** —
- **Files:** `nnls_fit.dart`, `tool/ingest/oil.dart`, `assets/pigments/oil.*`
- **Tasks:** per-λ non-negative least squares fitting K_i,S_i from the MPI pure+mixture reflectances with known ratios (design §4.2); train/held-out split; ship the oil artifact.
- **Exit criteria:** analyze clean; 100% touched; held-out mixtures predicted ≤ 5 ΔE00; coeffs ≥ 0.
- **Acceptance gate:** un-pend AC-9; `TestAC09_OilFit` green; **augment** from the synthetic placeholder.

### Result · Checkpoint  <!-- filled on completion -->

## Phase 7 — DATA-7: attribution + provenance (AC-11) — needs G-3 wording

- **Kind:** behavior · **Target AC:** AC-11 (full)
- **Depends on:** DATA-5, DATA-6 · **Blocks:** —
- **Files:** `NOTICE`/`ATTRIBUTION.md`, `pigment_table.dart`
- **Tasks:** finalize the MPI CC BY 4.0 notice + the Golden/RIT attribution per the granted permission wording (G-3); assert each paint's provenance reflects its source.
- **Exit criteria:** analyze clean; 100% touched; LICENSE MIT; notices present & correct; provenance per source.
- **Acceptance gate:** un-pend AC-11; `TestAC11_Attribution` green; **augment** the acrylic-wording placeholder.

### Result · Checkpoint  <!-- filled on completion -->

## Phase 8 — DATA-8: synthetic fixture hue faithfulness (enabler) — G-8

- **Kind:** enabler · **Target AC:** — (makes AC-17's Given "an in-gamut target reachable by the palette" real; makes every `synthPigments`-based AC render faithful hues)
- **Depends on:** DATA-1, ITEST-5 (G-2) · **Blocks:** SOLVER-6
- **Files:** `lib/src/data/synthetic_fixture.dart`; `assets/pigments/synthetic_{acrylic,oil}.json` (regenerated); any unit/AC test that hardcodes a rendered synthetic colour
- **Why (G-8, verified in the SOLVER-6 session 2026-10-17):** `_chroma` set each chromatic paint's **absorption K peak at its named hue's wavelength**, so the paint *absorbs* that hue and renders its **complement** — pure `phthalo_blue` = sRGB(0.687, 0.555, 0.300) (orange/tan), and white+blue tints move *toward* orange, not blue; `naphthol_red` (peakBin 22 ≈620 nm) renders cyan-ish; oil `ultramarine`/`yellow_ochre` likewise. So AC-17's cool-blue target sRGB(0.72, 0.76, 0.86) is unreachable (best ≈ 10.28 ΔE00) — a fixture defect, **not** a solver one (the optimizer already reaches ≤ 0.76 ΔE00 on genuinely reachable targets).
- **Tasks:**
  1. Correct `_chroma` so a paint **reflects** at its named hue: low absorption K near the hue's bin, higher K away from it (e.g. invert the Gaussian, `k = 0.05 + 0.9·(1 − e^{−d²})`), S flat & non-negative; `_white` unchanged. Choose each paint's hue bin so the rendered sRGB is consistent with its name (verify by rendering); keep the smooth, non-negative, "plausible but invented" D-7 spirit.
  2. Regenerate `assets/pigments/synthetic_{acrylic,oil}.json` with the encode script (+ trailing newline); the parity test pins the exact bytes.
  3. Re-run the **whole** suite (unit + acceptance default + run-pending) + coverage gate. Update only the unit/AC tests that hardcode a *rendered colour* that legitimately changes — record each change and its reason (never weaken an assertion). Confirm AC-18's control still holds (pure sRGB green stays unreachable with blue+red primaries → still flagged out-of-gamut) and AC-13's desaturation still holds (two differing hues).
  4. Tune the blue so the AC-17 cool-blue region is reachable ≤ 5 ΔE00 (so SOLVER-6 can un-pend AC-17 against a genuinely in-gamut target); record the reachable cool-blue region for SOLVER-6.
- **Exit criteria:** analyze clean; 100% of touched lines/branches; `phthalo_blue`/`naphthol_red` (and oil paints) render hues consistent with their names; whole suite green (default + run-pending, only later phases' ACs pending); AC-18 green; the AC-17 cool-blue region reachable ≤ 5 (recorded).
- **Acceptance gate:** *(enabler — un-pends no AC)* the whole acceptance suite stays green; **re-grade every un-pended AC test** with a fresh adversarial subagent (the fixture is a shared helper → neighbours may shift) → all A (or *B pending <phase>* with a row).

### Result · Checkpoint

**Done 2026-10-17.** Inverted the `_chroma` K Gaussian so a paint **reflects** at
its named hue (`k = 0.05 + 0.9·(1 − e^{−d²})`, `d=(i−peakBin)/6`, S flat 0.3,
`_white` unchanged) — the earlier non-inverted form peaked absorption K *at* the
hue, rendering the complement. Moved two peak bins so the rendered sRGB matches
the name: acrylic **phthalo_blue 4→6**, oil **yellow_ochre 10→18**
(naphthol_red 22 and oil ultramarine 6 render correctly once inverted, kept).
Peak bins chosen empirically by rendering each pure paint through the real
forward path (`forwardColour`).

- **Rendered hues now faithful** (pure paint, OKLCh h): phthalo_blue h≈275 (blue,
  sRGB(0.309,0.347,0.570)), naphthol_red h≈28 (warm red, sRGB(0.580,0.353,0.323)),
  oil ultramarine h≈275 (blue), oil yellow_ochre h≈87 (yellow,
  sRGB(0.548,0.480,0.326)). Blue/red hues differ 113° (AC-13 control intact).
- **Assets regenerated** — `assets/pigments/synthetic_{acrylic,oil}.json`
  rewritten via `PigmentArtifactCodec.encode(SyntheticFixture.artifact(m))+"\n"`;
  the `data_test.dart` parity test (byte-exact) passes.
- **No test hardcoded a rendered synthetic colour** that shifted — unit/AC tests
  are self-referential (`forward({…})` as target) or structural/relative, so none
  were edited (no assertion weakened).
- **Gates:** `dart analyze` clean; default suite **136 pass / 17 pending skipped**;
  run-pending red baseline correct — the only failures are the 13 later-phase
  unbuilt ACs (AC-7/8/9/10/11/12 data+forward, 21/22/23/24/25 tune+prod, 26/27
  stretch); coverage **32/32 lines** on the single touched file
  `synthetic_fixture.dart` (coverage gate PASS).
- **AC-18 control holds:** pure sRGB green stays out-of-gamut (best ΔE00 **32.40**,
  `outOfGamut` true) — palette is still white/blue/red, no green primary.
- **AC-17 target now reachable (recorded for SOLVER-6):** cool-blue sRGB(0.72,
  0.76,0.86) best ΔE00 **3.69**, `outOfGamut` false, recipe **white 0.917 +
  phthalo_blue 0.083**. Reachable cool-blue region = light, white-dominated blue
  tints (white fraction ≈ 0.88–0.97). In run-pending AC-17 now passes; SOLVER-6
  un-pends it.
- **Grade gate:** fresh adversarial subagent re-graded all 10 un-pended AC tests
  → **10 A, 0 downgrades**; AC-16 and AC-19 controls *strengthened* (their
  "tempting" targets now point at genuinely correct-hued paints). Band appended to
  `behavior-test-completeness-pigment-km-engine.md`.
- **Fix passes:** 0/3 (passed first full run).

**Checkpoint / Handoff.** Verification (from repo root, `export PATH="$HOME/development/flutter/bin:$PATH"`):
`dart analyze lib test` · `dart test` (default, green) ·
`PIGMENT_KM_RUN_PENDING=true dart test test/acceptance` (red baseline) ·
`bash tool/coverage_gate.sh HEAD`. `SyntheticFixture._chroma` is now hue-faithful;
`PigmentTable.load` builds from it directly (assets kept in parity by the test).
**For SOLVER-6 (AC-17):** the synthetic cool-blue target is genuinely in-gamut —
solve with white+phthalo_blue; best ΔE00 ≈ 3.69 today (SOLVER-6 may tighten the
optimizer but the fixture no longer blocks ≤5). **Drift to resolve (not DATA-8's
to fix):** `SOLVER.md` still lists SOLVER-6 *Depends on: SOLVER-5, FORWARD-3* and
neither plan lists DATA-8 as SOLVER-6's dependency, although G-8/DATA-8 was created
to unblock SOLVER-6 and FORWARD-3 is gated on G-3/G-4 real data — the SOLVER-6
dependency set needs a planner reconcile (drop FORWARD-3 if AC-17 is the synthetic
target; add DATA-8). `assets/*` and `tool/ingest/*` are DATA-module-owned but
`tool/ingest/` is untracked DATA-5/6 ingest material — left untouched, not staged.
