# Module COLOR — spectrum → colour backend

**Status:** Not started
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/colour/spectrum_to_colour.dart`, `lib/src/colour/gamut_map.dart`, `lib/src/colour/cmf_d65_weights.dart` (precomputed x̄·D65, ȳ·D65, z̄·D65 on the canonical grid), `lib/src/colour/oklch.dart`
**Depends on:** CORE · **Blocks:** FORWARD, STRETCH

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 2 (COLOR-2) | behavior | AC-1 | ⬜ Todo | | |
| 3 (COLOR-3) | behavior | AC-2 | ⬜ Todo | | |

## Interface reconciliation

Ports the Spectral.js spectrum→XYZ→sRGB + OKLCh gamut-map backend to Dart (design §2, §3.5, MIT — attribute in NOTICE). Precompute the three length-31 weight vectors so spectrum→XYZ is three dot products.

## Open gates

- **G-2** blocks all behavior phases.

## Phase 2 — COLOR-2: spectrum → colour (AC-1)

- **Kind:** behavior · **Target AC:** AC-1 (full)
- **Depends on:** CORE-2 · **Blocks:** COLOR-3, FORWARD-2
- **Files:** `cmf_d65_weights.dart`, `spectrum_to_colour.dart`
- **Tasks:** compute XYZ = Σ R·(CMF·D65)/Σ(ȳ·D65); XYZ→sRGB via the standard matrix + gamma encode; return `ColourValue`.
- **Exit criteria:** `dart analyze` clean; 100% line+branch on touched files.
- **Acceptance gate:** un-pend AC-1; `TestAC01_SpectrumToColour` green (ΔE00 ≤ 1 vs published).

### Result  <!-- filled on completion -->
### Checkpoint / Handoff  <!-- filled on completion -->

## Phase 3 — COLOR-3: OKLCh gamut mapping (AC-2)

- **Kind:** behavior · **Target AC:** AC-2 (full)
- **Depends on:** COLOR-2 · **Blocks:** FORWARD-2
- **Files:** `oklch.dart`, `gamut_map.dart`
- **Tasks:** sRGB↔OKLab↔OKLCh; gamut-map by binary-searching chroma down at fixed hue+L until in-gamut (Spectral.js approach); never hard-clip.
- **Exit criteria:** `dart analyze` clean; 100% line+branch on touched files; hue & L preserved within tol in tests.
- **Acceptance gate:** un-pend AC-2; `TestAC02_GamutMap` green.

### Result  <!-- filled on completion -->
### Checkpoint / Handoff  <!-- filled on completion -->
