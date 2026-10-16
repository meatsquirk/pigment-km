# Module COLOR — spectrum → colour backend

**Status:** ✅ Done — module complete (COLOR-2 ✅, COLOR-3 ✅)
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/colour/spectrum_to_colour.dart`, `lib/src/colour/gamut_map.dart`, `lib/src/colour/cmf_d65_weights.dart` (precomputed x̄·D65, ȳ·D65, z̄·D65 on the canonical grid), `lib/src/colour/oklch.dart`
**Depends on:** CORE · **Blocks:** FORWARD, STRETCH

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 2 (COLOR-2) | behavior | AC-1 | ✅ Done | 7.64M | 17m 38s |
| 3 (COLOR-3) | behavior | AC-2 | ✅ Done | 11.82M | 30m 37s |

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

### Result

OKLCh gamut mapper landed; AC-2 un-pended and green. COLOR module complete.

- **Landed:** `lib/src/colour/oklch.dart` (new) — the colour-space conversion primitives, extracted from `spectrum_to_colour.dart` so forward and inverse share one matched set (no duplicated matrices): `encodeGamma`, `xyzToLinearSrgb`, `linearSrgbToOklch` (moved; the COLOR-2 forward) plus the new inverses `oklchToLinearSrgb` (OKLCh→linear, Ottosson inverse constants) and `linearSrgbToXyz`. `lib/src/colour/gamut_map.dart` — `gamutMap`: the out-of-gamut signal is the OKLCh chroma (a predicted colour's displayable sRGB is already clamped); an in-gamut colour is returned unchanged, otherwise chroma is reduced at **fixed** OKLCh L+hue by a 40-step binary search for the largest in-gamut chroma (membership via the unclamped `oklchToLinearSrgb` within 1e-7), then re-encoded into a consistent (sRGB∈[0,1], XYZ, OKLCh) triple — never a hard clip. `spectrum_to_colour.dart` now imports the shared primitives (behaviour byte-equivalent).
- **Interface reconciliation (as the COLOR-2 handoff anticipated):** the OKLab/sRGB/XYZ maths were private in `spectrum_to_colour.dart`; COLOR-3 extracted them into `oklch.dart` (adding the two inverses) and re-covered both. `spectrum_to_colour.dart` is a reconciliation edit (its public signature and output are unchanged); AC-1 re-confirmed A against the moved code.
- **Verification:** `dart analyze` → No issues · unit `dart test` → **119 passed / 21 skipped / 0 failed** (new `test/gamut_map_test.dart`: gamutMap out-of-gamut + in-gamut-unchanged + oklch/xyz round-trips) · coverage gate (vs BASE `5a53564`) → **PASS** (`gamut_map.dart` 16/16, `oklch.dart` 42/42, `spectrum_to_colour.dart` 14/14) · acceptance default `dart test test/acceptance` → **13 passed / 21 skipped** (AC-2 moved skip→pass; was 12/22) · AC-2 under `PIGMENT_KM_RUN_PENDING=true` green. Coverage is line-only (CORE metric deviation); every branch (in-gamut early return, both search arms) exercised by test design.
- **Test maintenance (recorded — strengthening, not weakening):** (1) un-pending AC-2 removed its `pendingACs` row → added `'AC-2':'COLOR-3'` to `unpendedACs` (the bijection guard still pins all 27). (2) Removed the now-false `gamutMap throws UnimplementedError` stub assertion (and its now-empty COLOR group) from `test/backends_stub_test.dart`; its docstring updated. (3) **Hardened `TestAC02_GamutMap`** (grade gate, see below): its original Thens were vacuous (`mapped.srgb∈[0,1]` always holds — the gamma encoder clamps). Added, in two passes, a decisive assertion that the mapper's *reported* OKLCh converts back (via a new **independent** reference inverse `oklchToLinearSrgb` added to `test/acceptance/harness/colour_math.dart`, Ottosson constants, not the library export) to UNCLAMPED linear sRGB ∈ [−1e-6, 1+1e-6], plus an end-to-end hue/L consistency triple — so an out-of-gamut mapper that hides a hard-clipped channel behind the encoder is rejected.
- **Grades:** behaviour grade gate re-graded **every** un-pended AC test (AC-1, AC-2, AC-3, AC-4, AC-5, AC-14) in fresh independent subagents. AC-2 graded **B** (G4: the weak Thens let a hard-clip stopping ≤~0.006 chroma above the boundary pass), fixed in-phase over two passes and re-graded **A** each time by fresh graders (the unclamped-in-gamut check shrinks the survival window to ~5e-7 chroma). Others **A (re-confirmed)** — AC-1 through the moved-but-equivalent colour code; AC-5/AC-14 assert only relative ΔE00 between `forward` outputs, invariant to the extraction. Final: **6 A**.
- **Fix passes:** 2/3 (both on AC-2's grade: fix 1 the consistency triple — insufficient; fix 2 the unclamped-in-gamut check — A).
- **Tokens / Time:** 11.82M / 30m 37s.

### Checkpoint / Handoff

- **Frozen interfaces (don't reshape without a reconciliation note):**
  - `gamutMap(ColourValue) → ColourValue` — maps on the OKLCh chroma axis at fixed L+hue; returns a consistent triple; in-gamut input returned unchanged.
  - `oklch.dart` exposes `encodeGamma`, `xyzToLinearSrgb`, `linearSrgbToXyz`, `linearSrgbToOklch`, `oklchToLinearSrgb` (library-internal — NOT exported from the `pigment_km` barrel). `spectrum_to_colour.dart` and `gamut_map.dart` both import them.
  - Independent test reference `colour_math.dart` now also exposes `oklchToLinearSrgb` (the acceptance yardstick's own inverse; distinct from the library's — the AC-2 test imports the reference one via the barrel-free harness, the unit test hides it to use the library's).
- **Verification commands (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"` first. Analyze `dart analyze`; unit `dart test`; coverage `bash tool/coverage_gate.sh <BASE>`; acceptance default `dart test test/acceptance`, red-baseline `PIGMENT_KM_RUN_PENDING=true dart test test/acceptance`. Un-pend = delete the AC row in `pending.dart` **and** add it to `unpendedACs` in `pending_gate_test.dart` **and** drop its stub-throw row in `backends_stub_test.dart`.
- **Known gaps:** none for AC-1/AC-2. The COLOR module is complete; no further COLOR phases. `gamutMap` is available for any later phase that needs display-safe sRGB (SOLVER out-of-gamut/target handling may reuse it).
