# Module COLOR — spectrum → colour backend

**Status:** ✅ Done — COLOR-2 ✅, COLOR-3 ✅, COLOR-4 ✅ (10° observer re-base — G-9/D-14)
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/colour/spectrum_to_colour.dart`, `lib/src/colour/gamut_map.dart`, `lib/src/colour/cmf_d65_weights.dart` (precomputed x̄·D65, ȳ·D65, z̄·D65 on the canonical grid), `lib/src/colour/oklch.dart`. COLOR-4 additionally edits the **Lab reference white** used for ΔE00 in `lib/src/engine/inverse.dart` (`_d65White`) and the **independent yardstick white** in `test/acceptance/harness/colour_math.dart` — cross-module touches that must be serialized (run COLOR-4 before grading STRETCH-2/3; no concurrent FORWARD/SOLVER/TUNE phase).
**Depends on:** CORE · **Blocks:** FORWARD, STRETCH; **COLOR-4 blocks** DATA-5, FORWARD-3, TUNE-3 (and the oil fidelity of DATA-6)

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 2 (COLOR-2) | behavior | AC-1 | ✅ Done | 7.64M | 17m 38s |
| 3 (COLOR-3) | behavior | AC-2 | ✅ Done | 11.82M | 30m 37s |
| 4 (COLOR-4) | behavior | AC-1 (re-base) + whole-suite re-grade | ✅ Done | 14.90M | 30m 47s |

## Interface reconciliation

Ports the Spectral.js spectrum→XYZ→sRGB + OKLCh gamut-map backend to Dart (design §2, §3.5, MIT — attribute in NOTICE). Precompute the three length-31 weight vectors so spectrum→XYZ is three dot products.

**COLOR-4 (10° re-base, G-9):** the `spectrumToColour`/`gamutMap`/barrel **surface is unchanged** — only the *constants* move from the CIE 1931 2° observer to the CIE 1964 10° observer. Recompute the three `CMF·D65` weight vectors and `yBarD65Sum` from the 10° CMF, and move the **Lab reference white** (`_d65White` in `inverse.dart`, and the independent yardstick white in `colour_math.dart`) from the 2° D65 white `(0.95047, 1.0, 1.08883)` to the 10° D65 white — so XYZ→Lab→ΔE00 is computed in the same observer the Golden/RIT acrylic dataset publishes (D65/10°). The sRGB display matrix + gamma encode stay the standard sRGB ones (display encoding, not a colorimetric observer). This re-grounds AC-1's `refSpectrumColour` published reference and re-runs every colour-dependent AC.

## Open gates

- **G-2** blocks all behavior phases (resolved 2026-10-16).
- **G-9** resolved 2026-10-19 (adopt a 10° observer — Matt Quirk) → **implemented by COLOR-4**. Risk carried to G-5: if the MPI oil dataset publishes 2° Lab, DATA-6 oil fidelity must reconcile the observer (render MPI raw spectra through the 10° pipeline, or convert its published Lab) — COLOR-4 adopts 10° globally for the acrylic-first path and does not block on G-5.

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
- **Known gaps:** none for AC-1/AC-2. `gamutMap` is available for any later phase that needs display-safe sRGB (SOLVER out-of-gamut/target handling may reuse it). **Superseded by COLOR-4:** the 2° colour basis these phases built is re-based to a 10° observer in COLOR-4 (G-9); AC-1/AC-2 are re-confirmed there against the 10° basis.

## Phase 4 — COLOR-4: 10° observer re-base (AC-1 re-base + whole-suite re-grade)

- **Kind:** behavior · **Target AC:** AC-1 (re-based to the 10° observer) · **Re-grades:** every colour-dependent un-pended AC (see *Augments*)
- **Depends on:** COLOR-3 (edits the frozen colour files); **G-9 ✅ resolved** (adopt 10°). Soft prerequisite: confirm the MPI oil observer under **G-5** so oil fidelity isn't broken instead (does *not* block — acrylic is the D-2 first medium; the global pipeline goes 10° now).
- **Blocks:** DATA-5 (AC-7), FORWARD-3 (AC-12), TUNE-3 (AC-21) — their published-colour fidelity needs the 10° basis; and the oil fidelity path of DATA-6 (AC-9).
- **Files:** `lib/src/colour/cmf_d65_weights.dart` (recompute all three weight vectors + `yBarD65Sum` from the CIE 1964 10° CMF × D65 SPD on the 400–700@10 grid; update the provenance header 2°→10°), `lib/src/colour/spectrum_to_colour.dart` (doc only — surface unchanged; update the "CIE 1931 2°" comment), `lib/src/engine/inverse.dart` (`_d65White` → the 10° D65 reference white for `_xyzToLab`/`deltaE2000Xyz`), `test/acceptance/harness/colour_math.dart` (the independent yardstick's Lab reference white → 10°). Fixture: `refSpectrumColour`'s published colour recomputed for the 10° observer.
- **Tasks:**
  1. Source the CIE 1964 10° colour-matching functions and the D65 SPD on the canonical grid (same authoritative source as COLOR-2's 2° data — `colour-science`), fold into `xBar/yBar/zBar·D65`, recompute `yBarD65Sum`; record the 10° range-truncated white point in the header (the 10° perfect-diffuser white over 400–700 nm, analogous to COLOR-2's `(0.9494, 1.0, 1.0871)`).
  2. Move the Lab reference white in `inverse.dart` and in the acceptance yardstick `colour_math.dart` to the 10° D65 white, so XYZ→Lab→ΔE00 is observer-consistent with the dataset. Keep the sRGB display matrix + gamma unchanged.
  3. Re-ground the `refSpectrumColour` fixture's published target to its 10° value.
- **Exit criteria:** `dart analyze` clean; 100% line (+branch by design) on touched executable lines; **`spectrumToColour`/`gamutMap`/barrel public signatures byte-identical** (a reconciliation edit — constants + Lab-white only).
- **Acceptance gate:** AC-1 re-confirmed green against the 10° `refSpectrumColour` (ΔE00 ≤ 1); whole acceptance suite green (default **and** run-pending `PIGMENT_KM_RUN_PENDING=true`, `@stretch` still excluded); red baseline re-recorded (the pending ACs still fail for the right reason).
- **Augments (re-grade in fresh independent subagents — the DATA-8 pattern):** re-grade **AC-1** (re-based target) and every un-pended colour-dependent AC whose greenness or grade could move under the new basis — **AC-2** (gamut map), **AC-5** (self-mix/order colour equality), **AC-13** (desaturation chroma inequality), **AC-14** (normalize colour equality), **AC-15** (ΔE00 ranking), **AC-17** (in-gamut ≤5 absolute threshold), **AC-18** (out-of-gamut ΔE00), **AC-22** (chroma-penalty tie detection), **AC-23** (wet/dry L*C*h offset), **AC-25** (A/B ΔE00 report). Relative-only ACs (AC-5/14/15/18/25) are expected to re-confirm A unchanged; absolute-threshold ACs (AC-1/2/13/17/22/23) are the ones to watch. The not-yet-coded fidelity ACs (AC-7/9/12/21) are authored fresh against the 10° basis in their own phases (DATA-5/DATA-6/FORWARD-3/TUNE-3) — not re-graded here.
- **Test maintenance (anticipate, record in Result):** updating `refSpectrumColour`'s published colour and the two Lab reference whites is *re-grounding the yardstick to the approved observer* (G-9), not weakening any AC — record it with its reason. If `yBarD65Sum`'s exact value changes, the `yBarD65Sum == Σ yBarD65` unit assertion must still hold.

### Result

Colour pipeline re-based from the CIE 1931 2° to the CIE 1964 10° observer (G-9 / D-14); AC-1 re-confirmed green, whole suite green, 22 A.

- **Landed (constants/doc-only, no signature or logic change):**
  - `lib/src/colour/cmf_d65_weights.dart` — the three `CMF·D65` weight vectors + `yBarD65Sum` recomputed from the **CIE 1964 10°** CMF × D65 SPD on the 400–700@10 grid. `yBarD65Sum` 1056.5085298462 → **1161.6771622677738**. Header updated (observer, provenance, white points).
  - **Lab reference white** moved `(0.95047, 1.0, 1.08883)` → the standard 10° white **(0.94811, 1.0, 1.07304)** in `lib/src/engine/inverse.dart` (`_d65White`) **and** `lib/src/tune/wet_dry.dart` (`_d65White` — not in the plan's file list, but its own comment requires it stay in lock-step with `inverse.dart`; a stray 2° white there would defeat D-14) **and** the acceptance yardstick `test/acceptance/harness/colour_math.dart`. Doc comments in `spectrum_to_colour.dart` and `forward.dart` updated 2°→10°.
  - Fixture `refSpectrumColour.publishedXyz` and unit `canonicalD65` → the 10° white (both the perfect diffuser's white point under D65/10°); AC-1 test's hardcoded published-XYZ + "CIE 1931" comment updated.
- **How the 10° data was sourced (authoritative + validated):** regenerated with the `colour-science` package (the same source COLOR-2's 2° weights cite). The method was **validated by first reproducing the prior 2° vectors exactly** (`xBarD65[0]` and `yBarD65Sum` to 0 diff) before switching the CMF to 1964 10°. The standard ASTM-E308 D65/10° white (0.94811, 1.0, 1.07304) was used for the Lab reference (matching the repo's convention of the clean standard white and the observer the dataset's published Lab is computed against), confirmed against colour-science's xy-derived (0.94810, 1.0, 1.07305).
- **Verification:** `dart analyze` → 1 pre-existing `info` (`prefer_const_declarations` at `test/chroma_penalty_test.dart:38`, a TUNE-2 file present at BASE, untouched by COLOR-4 — not a regression; the 5 touched files are clean). Unit `dart test` → **207 passed / 7 skipped / 0 failed**. Coverage gate (vs BASE `b2eeace`) → **PASS**: `cmf_d65_weights.dart` no executable lines; `spectrum_to_colour.dart` 14/14; `forward.dart` 65/65; `inverse.dart` 146/146; `wet_dry.dart` 47/47. Acceptance default `dart test test/acceptance` → **29 passed / 7 skipped** (all 20 un-pended ACs green). Run-pending red baseline `PIGMENT_KM_RUN_PENDING=true dart test test/acceptance -x stretch` → **28 passed / 5 failed**, each pending AC red for the right reason naming its owner (AC-7→G-3/DATA-5, AC-9→G-4/DATA-6, AC-11→G-3/DATA-7, AC-12→FORWARD-3, AC-21→TUNE-3). `@stretch` AC-26/27 excluded.
- **Acceptance gate (AC-1):** re-confirmed green against the 10° `refSpectrumColour` — ΔE00 **0.084** ≤ 1 (published Lab is exactly (100,0,0); residual is the 400–700 nm truncation). Margin 0.92.
- **Grades:** fresh independent adversarial grader re-graded **every** un-pended AC (the DATA-8 pattern) — **22 A / 0 B, 0 downgrades, 0 fixes**. All absolute-threshold tests keep ≥0.9 ΔE00 head-room because engine colour and yardstick white moved in lockstep; relative/off-path tests are structurally insensitive. Details + per-AC margins in `behavior-test-completeness-pigment-km-engine.md` (COLOR-4 section).
- **Test maintenance (re-grounding to the approved observer G-9, not weakening any AC):** `refSpectrumColour.publishedXyz`, the two Lab reference whites (yardstick + wet_dry/inverse), the AC-1 published-XYZ assertion and the unit `canonicalD65` all moved to the 10° white. The `yBarD65Sum == Σ yBarD65` unit assertion still holds at the new value.
- **Fix passes:** 0/3 (green on the first full run).
- **Tokens / Time:** 14.90M / 30m 47s (incl. the re-grade subagent).

### Checkpoint / Handoff

- **Frozen 10° constants (don't reshape without a reconciliation note):**
  - `cmf_d65_weights.dart`: `xBarD65`/`yBarD65`/`zBarD65` (length 31) are the CIE 1964 10° CMF × D65 products; `yBarD65Sum = 1161.6771622677738`.
  - Lab reference white (ΔE00 maths): **(0.94811, 1.0, 1.07304)** — the standard D65/**10°** white, used identically in `inverse.dart` (`_d65White`), `wet_dry.dart` (`_d65White`) and the acceptance yardstick `colour_math.dart`. Keep these three in lock-step; a later phase that needs a Lab white must reuse this value.
  - `spectrumToColour`/`gamutMap`/barrel public signatures and the sRGB display matrix + gamma are **unchanged** from COLOR-3.
- **Verification commands (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"` first. Analyze `dart analyze`; unit `dart test`; coverage `bash tool/coverage_gate.sh <BASE>`; acceptance default `dart test test/acceptance`, red-baseline `PIGMENT_KM_RUN_PENDING=true dart test test/acceptance -x stretch`.
- **Green light for DATA-5 / FORWARD-3 / TUNE-3:** the colour pipeline now matches the Golden/RIT acrylic dataset's D65/10° published Lab, so published-colour fidelity ACs are built against this basis. **DATA-5 (AC-7) is now unblocked** — the G-3 acrylic data is in hand and the observer mismatch (G-9) that was its only remaining blocker is resolved. The dataset's published colours must be compared under the 10° white (it is now the engine's), with no observer conversion.
- **Oil risk (carried to G-5):** COLOR-4 adopts 10° **globally**. If the MPI oil dataset (DATA-6) publishes 2° Lab, its fidelity must reconcile the observer (render MPI raw spectra through the 10° pipeline, or convert its published Lab) — COLOR-4 does not block on G-5.
- **Known gaps:** none for AC-1/AC-2. The pre-existing `prefer_const_declarations` info in `test/chroma_penalty_test.dart:38` is inherited TUNE-2 debt in an untouched file (fix it in a TUNE-owned touch, not here).
