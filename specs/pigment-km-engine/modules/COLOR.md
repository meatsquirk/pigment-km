# Module COLOR — spectrum → colour backend

**Status:** In progress (COLOR-2 ✅; COLOR-3 startable)
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/colour/spectrum_to_colour.dart`, `lib/src/colour/gamut_map.dart`, `lib/src/colour/cmf_d65_weights.dart` (precomputed x̄·D65, ȳ·D65, z̄·D65 on the canonical grid), `lib/src/colour/oklch.dart`
**Depends on:** CORE · **Blocks:** FORWARD, STRETCH

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 2 (COLOR-2) | behavior | AC-1 | ✅ Done | 7.64M | 17m 38s |
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

### Result

Spectrum→colour backend landed; AC-1 un-pended and green.

- **Landed:** `lib/src/colour/cmf_d65_weights.dart` — precomputed `x̄·D65`, `ȳ·D65`, `z̄·D65` weight vectors (length 31) + `yBarD65Sum` normalizer, computed from the authoritative CIE 1931 2° CMF + CIE D65 SPD (400–700 @ 10 nm, as tabulated by `colour-science`); provenance in the file header. `lib/src/colour/spectrum_to_colour.dart` — `spectrumToColour`: three dot products → XYZ (÷ `yBarD65Sum`, so Y=1 for a perfect diffuser), XYZ→linear-sRGB (standard D65 matrix), gamma-encode (clamped) → display sRGB, and OKLCh from the *unclamped* linear sRGB (faithful chroma for COLOR-3's gamut map). Un-pended AC-1 in `pending.dart`.
- **Why the range truncation is fine:** over 400–700 nm the perfect-diffuser white is (0.9494, 1.0, 1.0871), ΔE00 ≈ 0.30 of the full-range D65 white (0.95047, 1.0, 1.08883) — well inside the AC's ΔE00 ≤ 1.
- **Verification:** `dart analyze` → No issues · unit `dart test` → **78 passed / 26 skipped / 0 failed** (8 new in `test/colour_test.dart`) · coverage gate (vs BASE `2563089`) → **PASS** (`spectrum_to_colour.dart` 39/39 lines; `cmf_d65_weights.dart` const data, no executable lines) · acceptance default `dart test test/acceptance` → **8 passed / 26 skipped** (AC-1 moved skip→pass; was 7/27). Coverage is line-only (CORE metric deviation); branches exercised by test design (black→linear gamma segment; blue→hue +360 wrap).
- **Test maintenance (recorded):** (1) un-pending AC-1 removed its `pendingACs` row → updated `test/acceptance/pending_gate_test.dart` to track un-pended ACs in an `unpendedACs` map so the anti-vacuous guard still pins all 27 (pending ⊎ un-pended = AC-1..27, bijection over the 27 phases) — the "cascade-edit" ITEST-1 anticipated (ITEST.md note). (2) Removed the now-false `spectrumToColour throws UnimplementedError` stub assertion from `test/backends_stub_test.dart` (gamutMap stub kept). Neither weakens an AC test.
- **Grades:** AC-1 (`TestAC01_SpectrumToColour`) re-graded by a fresh independent subagent now that the body is real → **A** (1 A / 0 B; no G1–G6 rule tripped — Given checked, When through the public surface, Thens measured against the harness's *independent* CIEDE2000, rejects the dropped-illuminant-weighting impl at ~0.7 ΔE00 margin). No augmentations assigned to AC-1; no other un-pended AC test exists to augment.
- **Fix passes:** 1/3 (first full run surfaced two stale shell-stage test assumptions — the pending bijection guard and the spectrumToColour stub test; both updated; green thereafter).
- **Tokens / Time:** 7.64M / 17m 38s.

### Checkpoint / Handoff

- **Frozen interfaces (don't reshape without a reconciliation note):**
  - `spectrumToColour(Spectrum) → ColourValue` returns consistent (srgb clamped-displayable, xyz normalized Y=1, oklch from unclamped linear). COLOR-3's `gamutMap` consumes this `oklch` to reduce chroma.
  - `cmf_d65_weights.dart` exposes `const xBarD65/yBarD65/zBarD65` (length 31) + `const yBarD65Sum`. Unit test asserts `yBarD65Sum == Σ yBarD65`.
- **For COLOR-3 (AC-2 gamut map, `oklch.dart` + `gamut_map.dart`):** the OKLab forward maths (linear-sRGB→OKLab→OKLCh, sign-preserving cbrt) currently live **private** in `spectrum_to_colour.dart` to keep COLOR-2 within its two declared files. COLOR-3 owns `oklch.dart` and needs the **inverse** (OKLCh→sRGB) for the chroma binary search; if it wants the forward too, extract the shared conversions from `spectrum_to_colour.dart` into `oklch.dart` and re-cover both (reconciliation note). The XYZ→sRGB matrix + gamma are the standard sRGB/D65 ones.
- **Verification commands (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"` first. Analyze: `dart analyze`. Unit: `dart test`. Coverage: `bash tool/coverage_gate.sh <BASE>`. Acceptance default: `dart test test/acceptance`. Un-pend = delete the AC row in `pending.dart` **and** add it to `unpendedACs` in `pending_gate_test.dart`.
- **Known gaps:** none for AC-1. Data attribution for CIE/D65 tables: standard CIE reference data (not MIT code); documented in the weights file header, not added to NOTICE (CORE-owned) — revisit if a dataset-attribution phase (DATA-7) decides it belongs there.

## Phase 3 — COLOR-3: OKLCh gamut mapping (AC-2)

- **Kind:** behavior · **Target AC:** AC-2 (full)
- **Depends on:** COLOR-2 · **Blocks:** FORWARD-2
- **Files:** `oklch.dart`, `gamut_map.dart`
- **Tasks:** sRGB↔OKLab↔OKLCh; gamut-map by binary-searching chroma down at fixed hue+L until in-gamut (Spectral.js approach); never hard-clip.
- **Exit criteria:** `dart analyze` clean; 100% line+branch on touched files; hue & L preserved within tol in tests.
- **Acceptance gate:** un-pend AC-2; `TestAC02_GamutMap` green.

### Result  <!-- filled on completion -->
### Checkpoint / Handoff  <!-- filled on completion -->
