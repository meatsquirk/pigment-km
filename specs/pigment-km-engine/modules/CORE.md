# Module CORE — package scaffold, grid, core types, engine interface

**Status:** In progress — CORE-1 done, next CORE-2
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `pubspec.yaml`, `LICENSE`, `NOTICE`/`ATTRIBUTION.md`, `README.md`, `analysis_options.yaml`, `lib/pigment_km.dart` (public exports), `lib/src/grid.dart`, `lib/src/types/*` (Spectrum alias, `Medium`, `MediumConfig`, `Pigment`, `Recipe`, `Provenance`, `MixOptions`), `lib/src/engine/mixing_engine.dart` (interface), `lib/src/engine/custom_km_engine.dart` + `lib/src/engine/spectral_baseline_engine.dart` (stubs), `tool/coverage_gate.*`
**Depends on:** — · **Blocks:** every other module

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 1 (CORE-1) | scaffold | — | ✅ Done | 3.61M | 6m44s (33m) |
| 2 (CORE-2) | shell | — | ⬜ Next | | |

## Interface reconciliation

The library's own public surface (design §10) is richer than Nuance's `MixingEngine` (bs-04): it is spectral/pigment-based and carries its own colour type `ColourValue` (sRGB + XYZ + OKLCh), **not** Flutter `ColorCoordinates` (D-3). Nuance adapts behind its interface — not this package's concern. Canonical grid is a shared constant (D-1). `Recipe`/`Pigment`/`Provenance` mirror the design-doc sketch; value-equal and `const`-constructible like the Nuance types.

## Open gates

- **G-1** (decision) blocks CORE-1: approve the spec. ✅ Resolved 2026-10-16: approved as-is — Matt Quirk.

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

### Result

Dart package scaffold stood up and verified.

- **Landed:** `pubspec.yaml` (SDK `^3.4.0`; dev-deps `test ^1.25.0`, `coverage ^1.9.0`, `lints ^4.0.0`; `publish_to: none` until the API ships), `analysis_options.yaml` (lints/recommended + strict casts/inference/raw-types + a few rules), `.gitignore`, `lib/pigment_km.dart` (entry point; `packageVersion()` marker — a function, not a `const`, so the gate has an executable line to prove itself), `test/smoke_test.dart`, `tool/coverage_gate.sh`, `test/acceptance/README.md` (runner convention). `LICENSE`/`NOTICE`/`README.md` pre-existed (initial repo setup) — left as-is.
- **Branch:** `feat/pigment-km-engine` created off `main` (`4d5ae8e`). GitHub remote already present (`origin/main`).
- **Verification:** `dart analyze` → No issues. `dart test` → 1/1 green. Coverage gate **proven**: PASS on clean tree (`lib/pigment_km.dart` 1/1 lines), FAIL on a planted untested branch (1/3, uncovered lines flagged), PASS again after revert; git-derivation mode also finds the touched file vs `BASE`. Acceptance suite: no tests yet (empty, green).
- **Coverage metric (justified deviation):** the Dart test-runner flow (`dart test --coverage` + `coverage:format_coverage`) emits **line** coverage only — `format_coverage` has no `--branch-coverage` option in this flow — so the gate enforces 100% line coverage of touched `lib/**.dart`, and enforces branch records only if present. Branches are exercised by test design; acceptance + grade gates verify per phase. Recorded here rather than treated as a passing branch gate.
- **Fix passes:** 0/3 (passed first run).

### Checkpoint / Handoff

- **Toolchain:** `dart` is NOT on the non-interactive PATH — prepend `export PATH="$HOME/development/flutter/bin:$PATH"` (Flutter bundles Dart 3.13.5). The gate script does this fallback itself.
- **Verification commands (reuse these):**
  - Analyze: `dart analyze`
  - Unit: `dart test`
  - Coverage gate (touched vs base): `bash tool/coverage_gate.sh <BASE>` — or `bash tool/coverage_gate.sh --files <paths…>` for explicit files. PASS/FAIL + per-file line counts.
  - Acceptance default: `dart test test/acceptance`
  - Acceptance red-baseline: `PIGMENT_KM_RUN_PENDING=true dart test test/acceptance`
- **Baseline:** empty package, `dart test` 1/1 green, analyze clean, at commit for CORE-1.
- **Known gaps:** none. No branch-coverage enforcement in the lcov gate (see Result) — expected, documented.
- **Next (CORE-2):** core value types + `CanonicalGrid` (400–700@10, 31 bins) + `Spectrum` alias + `abstract interface class MixingEngine` + stub `CustomKmEngine`/`SpectralBaselineEngine` (throw `UnimplementedError`) + `reflectanceOf` read endpoint; export the public surface from `lib/pigment_km.dart` (replace the `packageVersion()` marker with the real exports). Unit-cover type constructors / equality / grid invariant to 100%.

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
