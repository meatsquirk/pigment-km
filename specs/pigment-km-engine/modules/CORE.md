# Module CORE — package scaffold, grid, core types, engine interface

**Status:** Not started
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `pubspec.yaml`, `LICENSE`, `NOTICE`/`ATTRIBUTION.md`, `README.md`, `analysis_options.yaml`, `lib/pigment_km.dart` (public exports), `lib/src/grid.dart`, `lib/src/types/*` (Spectrum alias, `Medium`, `MediumConfig`, `Pigment`, `Recipe`, `Provenance`, `MixOptions`), `lib/src/engine/mixing_engine.dart` (interface), `lib/src/engine/custom_km_engine.dart` + `lib/src/engine/spectral_baseline_engine.dart` (stubs), `tool/coverage_gate.*`
**Depends on:** — · **Blocks:** every other module

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 1 (CORE-1) | scaffold | — | ⬜ Next (G-1) | | |
| 2 (CORE-2) | shell | — | ⬜ Todo | | |

## Interface reconciliation

The library's own public surface (design §10) is richer than Nuance's `MixingEngine` (bs-04): it is spectral/pigment-based and carries its own colour type `ColourValue` (sRGB + XYZ + OKLCh), **not** Flutter `ColorCoordinates` (D-3). Nuance adapts behind its interface — not this package's concern. Canonical grid is a shared constant (D-1). `Recipe`/`Pigment`/`Provenance` mirror the design-doc sketch; value-equal and `const`-constructible like the Nuance types.

## Open gates

- **G-1** (decision) blocks CORE-1: approve the spec.

## Phase 1 — CORE-1 scaffold

- **Kind:** scaffold
- **Target AC:** —
- **Depends on:** — (G-1) · **Blocks:** CORE-2
- **Files:** `pubspec.yaml`, `analysis_options.yaml` (lints), `LICENSE` (MIT), `README.md`, `.gitignore`, `test/smoke_test.dart`, `tool/coverage_gate.sh` (or `.dart`), GitHub remote
- **Tasks:**
  1. Init the Dart package (`dart create -t package`), set SDK constraint, add dev-deps `test`, `coverage`; MIT `LICENSE`; README stating the MIT + attribution framing (design §13).
  2. Create the GitHub remote (user provides URL), push `main`, open `feat/pigment-km-engine`.
  3. Stand up the unit+coverage gate: `dart test` + `dart test --coverage=coverage` → lcov via `package:coverage format_coverage`; a `tool/coverage_gate` script that computes touched-file line+branch coverage and fails on a gap.
  4. Record the baseline run (empty package green) and the acceptance runner convention (`test/acceptance/`, `PIGMENT_KM_RUN_PENDING`).
- **Exit criteria:** `dart test` green on the empty package; `dart analyze` clean; coverage gate **proven** — passes on the clean tree and fails on a planted uncovered branch; baseline recorded in the Checkpoint.

### Result  <!-- filled on completion -->

### Checkpoint / Handoff  <!-- filled on completion -->

## Phase 2 — CORE-2 shell: core types + engine interface

- **Kind:** shell
- **Target AC:** —
- **Depends on:** CORE-1 · **Blocks:** COLOR, KM, DATA, FORWARD, SOLVER, TUNE, PROD, STRETCH, ITEST-1
- **Files:** `lib/src/grid.dart`, `lib/src/types/*.dart`, `lib/src/engine/mixing_engine.dart`, `lib/src/engine/custom_km_engine.dart`, `lib/src/engine/spectral_baseline_engine.dart`, `lib/pigment_km.dart`
- **Tasks:**
  1. `CanonicalGrid` (400–700@10, 31 bins) + `Spectrum = Float32List` alias with a length invariant check.
  2. Value types: `Medium{acrylic,oil}`, `MediumConfig{medium,k1,k2,wetDry}`, `Provenance{measured,calculated,estimated,confirmed}`, `Pigment{id,name,pigmentIndex,medium,k,s,opacity,provenance,sourceRef}`, `Recipe{medium,parts,colour,deltaE00,provenance,outOfGamut,verdict}`, `ColourValue{srgb,xyz,oklch}`, `MixOptions{maxPaints,topK,gamutThreshold,...}` — value-equal, `const`.
  3. `abstract interface class MixingEngine { ColourValue forward(Map<String,double> mix); List<Recipe> inverse(ColourValue target, List<Pigment> palette, MixOptions opts); Spectrum reflectanceOf(Map<String,double> mix); }`.
  4. Stub `CustomKmEngine` and `SpectralBaselineEngine` implementing it with `throw UnimplementedError()` bodies (behavior phases fill them); export the public surface from `lib/pigment_km.dart`.
- **Exit criteria:** `dart analyze` clean; unit tests cover the type constructors / equality / grid invariant to 100%; stubs throw; `dart test` green; behavior unchanged (nothing solves yet). The `reflectanceOf` read endpoint exists for the acceptance suite's spectral assertions.

### Result  <!-- filled on completion -->

### Checkpoint / Handoff  <!-- filled on completion -->
