# Module DATA — datasets, ingestion, build artifact, attribution

**Status:** Not started
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/data/pigment_table.dart` (loader), `lib/src/data/artifact_format.dart`, `lib/src/data/resample.dart`, `lib/src/data/masstone_tint.dart`, `lib/src/data/nnls_fit.dart`, `assets/pigments/*` (shipped build artifacts, medium-tagged), `NOTICE`/`ATTRIBUTION.md`, `tool/ingest/*` (offline ingest scripts, not shipped at runtime)
**Depends on:** CORE, COLOR, KM · **Blocks:** FORWARD-3, SOLVER (real palette), TUNE-3

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 1 (DATA-1) | shell | — | ⬜ Todo | | |
| 2 (DATA-2) | behavior | AC-8 | ⬜ Todo | | |
| 3 (DATA-3) | behavior | AC-6 | ⬜ Todo | | |
| 4 (DATA-4) | behavior | AC-10 | ⬜ Todo | | |
| 5 (DATA-5) | behavior | AC-7 | ⬜ Todo (G-3) | | |
| 6 (DATA-6) | behavior | AC-9 | ⬜ Todo (G-4) | | |
| 7 (DATA-7) | behavior | AC-11 | ⬜ Todo (G-3) | | |

## Interface reconciliation

Build-time ingest (design §4, SI D6) produces a compact medium-tagged artifact of K,S vectors on the canonical grid; the runtime only *loads* it (no recompute). Acrylic ships turnkey K,S (design §4.1); oil's K,S are fit from mixtures (§4.2). Ingest lives in `tool/ingest/` (offline), the artifact under `assets/`. The synthetic fixture (D-7) ships a tiny hand-authored table so the suite runs before the real data lands.

## Open gates

- **G-3** (dependency): the Golden/RIT acrylic data + its fields/k1,k2/attribution wording → blocks DATA-5, DATA-7.
- **G-4** (dependency): the MPI oil dataset + mixtures → blocks DATA-6.
- **G-5** (decision): per-medium k1,k2 + S-normalization (folds into G-3/G-4).

## Phase 1 — DATA-1 shell: artifact format + loader + fixture

- **Kind:** shell · **Target AC:** —
- **Depends on:** CORE-2 · **Blocks:** ITEST-1, all DATA behavior
- **Files:** `artifact_format.dart`, `pigment_table.dart`, `assets/pigments/synthetic.*`, `NOTICE`/`ATTRIBUTION.md` scaffold
- **Tasks:** define the serialized artifact schema (medium, per-paint id/name/pigmentIndex/K/S/opacity/provenance/sourceRef); `PigmentTable.load(Medium)` reading it; ship the synthetic fixture; scaffold the NOTICE with the MPI CC BY 4.0 block (design §13.4) and a Golden/RIT placeholder.
- **Exit criteria:** analyze clean; 100% touched; `load(acrylic)`/`load(oil)` return the fixture; the suite can observe pigment fields; behavior unchanged.

### Result  <!-- filled on completion -->
### Checkpoint / Handoff  <!-- filled on completion -->

## Phase 2 — DATA-2: resample onto the canonical grid (AC-8)

- **Kind:** behavior · **Target AC:** AC-8 (full)
- **Depends on:** DATA-1 · **Blocks:** DATA-3
- **Files:** `resample.dart`
- **Tasks:** linear (or documented) resample from a native grid (380–730 / 400–700) onto 400–700@10; endpoint handling; use in ingest.
- **Exit criteria:** analyze clean; 100% touched; length 31; interior + endpoint interpolation correct.
- **Acceptance gate:** un-pend AC-8; `TestAC08_Resample` green.

### Result · Checkpoint  <!-- filled on completion -->

## Phase 3 — DATA-3: artifact fields loaded (AC-6)

- **Kind:** behavior · **Target AC:** AC-6 (full)
- **Depends on:** DATA-2 · **Blocks:** DATA-4
- **Files:** `pigment_table.dart`, `artifact_format.dart`
- **Tasks:** full load path populating every field; medium tagging; provenance + sourceRef from the artifact.
- **Exit criteria:** analyze clean; 100% touched; every paint exposes all fields; medium matches.
- **Acceptance gate:** un-pend AC-6; `TestAC06_Artifact` green.

### Result · Checkpoint  <!-- filled on completion -->

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
