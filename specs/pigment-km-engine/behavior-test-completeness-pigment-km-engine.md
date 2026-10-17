# Behaviour-test completeness grid — pigment-km-engine

Grades for the acceptance suite's AC tests, by the G1–G6 rubric
(`references/acceptance-suite.md`). Each AC-test phase adds its band; a fresh
independent subagent grades (never the test author). "Grade what the code does,
pending or not."

## Band 1 — ITEST-2 (AC-1…AC-9) · graded 2026-10-16

Grader: fresh general-purpose subagent, adversarial, G1–G6 + harness rubric.
Result after the in-phase fixes: **8 A, 1 B pending DATA-6**.

| AC | Test | Grade | Notes |
|---|---|---|---|
| AC-1 | TestAC01_SpectrumToColour | A | ΔE00 ≤ 1 to the D65 white point (independent yardstick) + Y≈1 + sRGB white; rejects wrong normalization/illuminant weighting. *Flag (G5 floor met): single white fixture — a second non-white published target would harden it (available post DATA-5).* |
| AC-2 | TestAC02_GamutMap | A | In-gamut + L/hue preserved + chroma reduced + `mapped != per-channel clamp`; rejects the hard clip. |
| AC-3 | TestAC03_KmRoundTrip | A | **Fixed in-phase (was B/G5).** The round-trip alone can't reject the branch-sign swap (roots are reciprocals, `f(R)=f(1/R)`); now asserts the intermediate reflectance R∞ ∈ [0,1] (the +√ branch gives R>1) plus the K/S=0→R=1 known point. |
| AC-4 | TestAC04_Saunderson | A | internal→measured→internal per bin + control (same input → different measured per medium; measured ≠ input); rejects no-op and one global k1,k2. |
| AC-5 | TestAC05_TwoConstantMix | A | **Hardened in-phase (grader flag).** Self-mix idempotence + order-independence + controls: mix ≠ each pure, and 25/75 ≠ 75/25 ≠ 50/50 (rejects a volume-ignoring mix). Volume *normalization* is AC-14's (FORWARD-2). |
| AC-6 | TestAC06_Artifact | A | Every paint, every field at grain + `load == decode(shipped asset)`. **Green at baseline** (shell loader already satisfies it). *Flag: asset path hardcoded `assets/pigments/synthetic_<medium>.json` — DATA-3/DATA-5 must keep or update it if the shipped artifact is renamed.* |
| AC-7 | TestAC07_RoundTripFidelity | A (data-limited) | Live executable Then (ΔE00 ≤ 0.5 for every paint via the independent yardstick) behind a precondition that fails at baseline naming G-3/DATA-5. Augmentation: DATA-5 switches the fixture to the shipped acrylic table (no test rewrite). |
| AC-8 | TestAC08_Resample | A | Linear-ramp resample: length 31 + exact value at every canonical bin + endpoints; rejects nearest-bin/index-misplaced copy. |
| AC-9 | TestAC09_OilFit | **B pending DATA-6** | Precondition-only at baseline (fails naming G-4/DATA-6). Its executable Then (per-λ NNLS fit on train, held-out ΔE00 ≤ 5, coeffs ≥ 0, disjoint split) needs the MPI oil fit API + data, both gated on G-4/G-5 (exact fields unconfirmed). Deliberately NOT designed ahead of its gate — the rubric's sanctioned "B pending <phase>" exception; augmentation row owned by DATA-6 (must add the full Then, not merely flip `isReal`). |

### Rejects-coverage flags (no grade change)
- **AC-7**: renders via `spectrumToColour(kmReflectance(·))` with no Saunderson step, matching the spec's "rendered to its *opaque reflectance*", so the catalogue's broader "wrong k1,k2" reject is out of this test's scope (KM-3/AC-4 covers Saunderson).
- **AC-6**: `Provenance.values contains p.provenance` is near-vacuous (enum is non-null) but the AC only requires "provenance set"; tier *correctness* is AC-24's (PROD-2).

## Band 2 — ITEST-3 (AC-10…AC-18) · graded 2026-10-16

Grader: fresh independent general-purpose subagent, adversarial, G1–G6 + the band
catalogue. Initial result **6 A, 2 A (data-limited), 1 B (AC-15)**; AC-15's B fixed
in-phase (fix pass 1/3). Final: **9 A** (AC-11, AC-12 data-limited). The grader
also verified the independent reference maths (`srgbToXyz`, `srgbToOklch`,
in-test `_tintReflectance`, `deltaE00`) are self-contained and a trustworthy
yardstick — AC-10 calls no library KM at all.

| AC | Test | Grade | Notes |
|---|---|---|---|
| AC-10 | TestAC10_MasstoneTint | A | Derived (K,S) must re-predict the masstone + all 3 tints to 1e-3 through the test's OWN independent two-constant KM reference with the fixed white; over-determined (4 curves × 31 bins, 2 unknowns/bin). Rejects masstone-alone (right K/S ratio, wrong S scale → mispredicts the white-diluted tints) and ignoring white's K_w,S_w. |
| AC-11 | TestAC11_Attribution | A (data-limited) | Live now: LICENSE exists + MIT; NOTICE exists + CC BY 4.0 + Asadi/Babaei/Seidel + "changes" + RIT; every loaded paint `estimated` + `synthetic:` ref. Real-source provenance Then (measured→Calculated) behind the `acrylicPublishedPlaceholder.isReal` precondition naming DATA-7/G-3 (the AC-7 data-limited pattern). *Flag (no change): "states changes" is a lowercase `contains('changes')`; DATA-7 tightens to the agreed wording.* |
| AC-12 | TestAC12_ForwardFidelity | A (data-limited) | The discriminating Then (`deltaE00(forward(parts), measured) ≤ 5` via the independent yardstick + parts-Σ1 check) is fully written against the existing surface, gated behind `measuredMixturesPlaceholder.isReal` naming FORWARD-3 (AC-7 pattern, not AC-9). *Flag: ΔE00 ≤ 5 is loose, so the single-constant/ignores-S reject is a real-data property — FORWARD-3's measured mixtures must separate a 2- from a 1-constant forward.* |
| AC-13 | TestAC13_Desaturation | A | Given: each pure paint chromatic (c>0.04), hues differ >20° via public `forward`. Then: `kmMix.oklch.c < srgbToOklch(midpoint-sRGB-blend).c`. An RGB-blending engine → chroma not strictly lower → fails. Rejects the natural-colour-vs-RGB wrong impl. *Flag: strict `<` on OKLab chroma (library vs harness, both Ottosson) — robust if desaturation is non-trivial.* |
| AC-14 | TestAC14_Normalize | A | Given asserts rawSum≈3≠1. Then colour(2:1)==colour(2/3:1/3) ΔE00<1e-6; CONTROL 6:3 also matches (rejects raw weights); CONTROL 1:2 differs >1e-3 (rejects collapse-to-constant). |
| AC-15 | TestAC15_RankedPreferFewer | A | **Fixed in-phase (was B/G5+G4).** Added `recipes.length ≥ 2` so the best-first monotonicity + membership + Σ1 checks are non-vacuous — rejects a single-recipe unranked/unstable or dataset-leaky solver. The prefer-fewer-on-tie reject needs a constructed equal-ΔE00 2-vs-3-paint tie that only the built solver can produce → **augmentation owned by SOLVER-3** (limited per G5). |
| AC-16 | TestAC16_PaletteOnly | A | Palette excludes `naphthol_red` (asserted absent) against a reddish target; every recipe paint ∈ palette. Rejects a solver reaching into the full dataset (it would pull the red). |
| AC-17 | TestAC17_InGamut | A | `best.deltaE00 ≤ 5` + `outOfGamut isFalse`; rejects stopping early above 5. *Flag (no change): in-gamut Given assumed (SOLVER-6 confirms the reachable target; G-6 adds held-out validation); a fake-perfect solver is caught only by AC-18's control — the intended AC-17/AC-18 pairing.* |
| AC-18 | TestAC18_OutOfGamut | A | Control: target chroma >0.2 (pure green, no green primary → genuinely unreachable). Then `outOfGamut isTrue` + `deltaE00 > 5`. Rejects a solver returning the nearest mix unflagged (a false recipe). The honesty control partnering AC-17. |

## Band 3 — ITEST-4 (AC-19…AC-27) · graded 2026-10-16

Grader: fresh independent general-purpose subagent, adversarial, G1–G6 + the band
catalogue, matched to the Band 1/2 standard. Result **6 A, 1 A (data-limited), 2 B
pending** — no G-rule failures; all downgrades are the rubric's sanctioned gate/
data deferrals (AC-9 "B pending DATA-6" precedent; AC-7/11/12 "A data-limited"
pattern). Fix passes 0/3 (passed first run). Public-surface compliance PASS for all
9 (imports only the package barrel + harness; Givens built via `PigmentTable.load`,
the public `Pigment(...)` constructor, `MixOptions`, `configForMedium`,
`WetDryTransform`, the independent `colour_math` yardstick).

| AC | Test | Grade | Notes |
|---|---|---|---|
| AC-19 | TestAC19_CrossMedium | A | Given: palette `containsAll {acrylic, oil}` (both media present, so a medium-ignoring solver *could* cross). Then at grain: every recipe `media hasLength(1)` and `media.single == r.medium`. Rejects a cross-medium solver. *Flag (G5 floor met): the catalogue's explicit cross-medium-tempting control is not constructed (generic grey target); SOLVER-5 should add an engineered cross-medium-optimal target.* |
| AC-20 | TestAC20_Performance | A | Given `palette.length == 15` before the When; timed `inverse(topK:3)`; Then nonempty + `length ≤ 3` + `elapsed ≤ 2 s` (SI NFR grain). Rejects an exponential search. *Note: 15 ids are clones of the synthetic K,S; the solver still sees 15 ids (search size is what's timed). Exclusive-lane is a runner concern, not test design.* |
| AC-21 | TestAC21_NoNeon | A (data-limited) | Live executable Then on the placeholder synthetic palette: no pure/50-50 mixture exceeds `chromaCeiling 0.25`; a muted earth target reachable (`ΔE00 ≤ 5`, `outOfGamut isFalse`); the neon target (`oogColour`) flagged `outOfGamut`. Rejects a neon-admitting palette and a dishonest match. **Augmentation owned by TUNE-3.** *Flag (the data-limit): unlike AC-7 it does not gate behind an `isReal` precondition — it trusts a provisional in-test ceiling (0.25); TUNE-3 must ship the curated palette AND confirm/tune the exact ceiling (harden, not merely swap data).* |
| AC-22 | TestAC22_ChromaPenalty | A | G2: behaviour comes from `MixOptions(chromaPenalty:)`, not a script override. Penalty-off ranking asserted ΔE00-monotonic (rejects a penalty leaking into the plain rank); on a ΔE00 tie with a chroma gap the lower-chroma member must rank ahead (`posLo < posHi`) — rejects a no-effect penalty and one that always dominates ΔE00. **Augmentation owned by TUNE-2:** `expect(sawTie, isTrue)` requires a guaranteed equal-ΔE00 2-vs-3-paint tie the synthetic solve won't deterministically produce, so TUNE-2 (the un-pending phase) must construct the tie together with the un-pend (same AC-15/SOLVER-3 treatment). |
| AC-23 | TestAC23_WetDry | A | Given: `wet`/`dry` nonempty + acrylic documents a non-identity offset (`configForMedium(acrylic).wetDry != WetDryTransform.none`). Thens at grain: parts equal within 1e-9 (rejects a re-solve that changes parts), colour shift `> 0.5` ΔE00 (rejects a no-op), dry darker (`xyz.y` lower) + hue-shifted (`> 0.5°`), each direction-guarded by the documented offset. *Flag for G-2 (interface): wet/dry is observed via `inverse(MixOptions.wet)`+`Recipe.colour` because `forward()` takes no options; TUNE-4/the interface must make wet/dry a post-prediction state transform (or add `forward(mix, opts)`) so the best recipe is stable across states. The catalogue reject ("one that re-solves and changes parts") endorses the parts-unchanged check — no downgrade.* |
| AC-24 | TestAC24_Provenance | A | Supplying a paint's provenance via the public `Pigment` constructor is legitimate input (its honesty tier); the *recipe's* derived provenance is read from the solve, not overridden (G2). Given: calc recipes nonempty; the single-tube solve verified to use the tube (`parts.keys contains tube.id`). Exact enum equality (G4). Two cases separate the rejects: calculated-input→Calculated (rejects "Measured/Estimated from measured data"); user tube→Measured (rejects an always-Calculated model). |
| AC-25 | TestAC25_ABEngines | A | Given: both builders `isA<MixingEngine>`. Interchangeability proven structurally: both driven through one `MixingEngine`-typed closure with the identical `inverse(target, palette, opts)` call — a baseline wired differently would not satisfy it. Then reports each engine's ΔE00 across the shared swatch set (nonnegative + finite). *Flag (no downgrade): the ΔE00 Then is intentionally loose — an interface-parity AC makes no accuracy claim (that is AC-7/12/17's job).* |
| AC-26 | TestAC26_Glazing (@stretch) | **B pending STRETCH-2** | Sanctioned deferral behind the still-open G-7 (AC-9 "B pending DATA-6" analogue). Body is a pure scope-gate precondition (`expect(_stretchScopeApproved, isTrue)` naming G-7); the finite-thickness layering API is deliberately NOT frozen before scope approval, and the full Given/When/Then/Rejects (incl. the X→∞ → opaque-form control) is documented in-place for STRETCH-2. No live Then against the current surface (so not "A data-limited"). **Augmentation owned by STRETCH-2.** |
| AC-27 | TestAC27_Metamerism (@stretch) | **B pending STRETCH-3** | Same sanctioned deferral behind G-7. Scope-gate precondition naming G-7; the multi-illuminant metamerism-index API not frozen until scope approval; the `illuminants` fixture (d65 + warm) is already staged, and the full scenario (incl. the single-illuminant reject) is documented for STRETCH-3. **Augmentation owned by STRETCH-3.** |

### Carry-forward flags for the owning phases
- **AC-19 (SOLVER-5):** ✅ RESOLVED in the SOLVER-5 re-grade below — a second-medium-reachable control added (a true cross-medium-blend target is physically inexpressible: the forward model throws on any cross-medium mix).
- **AC-21 (TUNE-3):** confirm/tune the real naturalistic chroma ceiling (harden), don't merely swap in the shipped palette.
- **AC-22 (TUNE-2):** construct the guaranteed equal-ΔE00 2-vs-3-paint tie the test depends on, together with the un-pend (until then the test is over-constrained on `sawTie`).
- **AC-23 (TUNE-4 / G-2):** resolve the forward-vs-inverse wet/dry interface so the best recipe is stable across wet/dry states.

## Behaviour re-grade — KM-2 (un-pended AC-1, AC-3) · graded 2026-10-16

Grader: fresh independent general-purpose subagent, adversarial, G1–G6; given the
Band 1 grid and asked to justify any downgrade against a named rule. The behaviour
grade gate re-grades **every un-pended AC test** now that KM-2's `kmReflectance`/
`kmFunction` run against real code. Result: **2 A** (no downgrade from Band 1); fix
passes 0/3.

| AC | Test | Grade | Notes |
|---|---|---|---|
| AC-1 | TestAC01_SpectrumToColour | A (re-confirmed) | Code unchanged since COLOR-2. Given checked through the public surface (spectrum length 31, published XYZ = D65 white, published sRGB = white); When runs real `spectrumToColour`; Then ΔE00 ≤ 1 vs the independent CIEDE2000 yardstick + Y≈1 + sRGB white. Rejects a backend that drops `yBarD65Sum` normalization or mis-weights the illuminant. Same unchanged G5-floor flag (single white fixture; a non-white published target hardens it post DATA-5). |
| AC-3 | TestAC03_KmRoundTrip | A | Now live against the real KM physics. Given checked through the public surface (`koverS` from `synthPigments()`, each bin finite and > 0) before the When; When runs the real barrel `kmReflectance` → `kmFunction`. Three independent Thens pin the physics: (1) reflectance ∈ [0,1] at every bin — **rejects the wrong (+√) root** (R>1 for x>0; the round-trip alone cannot, since the two roots are reciprocals and f(R)=f(1/R)); (2) K/S=0 → R=1 (1e-5) known reference point; (3) `kmFunction∘kmReflectance` round-trips to 1e-5 — rejects a dropped constant in f(R) (e.g. missing the 2× doubles K/S). Prior "fixed in-phase (was B/G5)" note confirmed holding green against real code. |

## Behaviour re-grade — KM-3 (un-pended AC-1, AC-3, AC-4) · graded 2026-10-16

Grader: fresh independent adversarial subagent, G1–G6; given the Band 1 + KM-2
grids and asked to justify any downgrade against a named rule. First pass found
**AC-4 = B** (G5/concern-c): `TestAC04_Saunderson`'s round-trip is mutually-inverse
by construction and the two controls differ only in `k1`, so a k2-dropping forward
`R_m = k1 + (1−k1)·R_i` (invertible, per-medium distinct) passed — the k2
internal-reflection term was unverified, and the suite has no other Saunderson
check (AC-7 renders with no Saunderson step). **Fixed in-phase (fix pass 1/3):**
added an independent full-formula forward reference `refMeasured` asserted per bin
for **both** media + a hand-computed fixed anchor (R_i=0.2 → R_m=0.12727273) + the
documented-constant pin. A second fresh grader re-graded **AC-4 = A**, tracing that
the no-op, single-global-k1,k2, and k2-dropping forwards now each fail ≥2
assertions. Result: **3 A** (AC-1, AC-3 re-confirmed; AC-4 B→A).

| AC | Test | Grade | Notes |
|---|---|---|---|
| AC-1 | TestAC01_SpectrumToColour | A (re-confirmed) | Code untouched by KM-3 (no shared helper touched). Same unchanged G5-floor flag (single white fixture; a non-white published target hardens it post DATA-5). |
| AC-3 | TestAC03_KmRoundTrip | A (re-confirmed) | `reflectance.dart` untouched by KM-3; range check still rejects the +√ root, round-trip 1e-5 still rejects a dropped f(R) constant. |
| AC-4 | TestAC04_Saunderson | A | **B→A, fixed in-phase.** Round-trip per bin (1e-5) + independent full-formula `refMeasured` per bin for acrylic **and** oil + hand anchor (bin 0 = 0.12727273) + distinctness & not-no-op controls. Pins the k2 term; rejects no-op, one global k1,k2, and the k2-dropping forward. *Flags (non-blocking): the test pins the documented defaults k1=0.04/k2=0.6 and the 0.12727273 anchor, so G-5's authoritative constants must update pin+anchor in lockstep; acrylic/oil share k2=0.6 (differ only in k1), but k2 is fully pinned via `refMeasured` + anchor rather than the medium contrast.* |

## Behaviour re-grade — FORWARD-2 (un-pended AC-5, AC-14; re-confirmed AC-1, AC-3, AC-4) · graded 2026-10-16

Grader: fresh independent adversarial subagent, G1–G6; given the prior grids and
asked to justify any downgrade against a named rule, now that
`CustomKmEngine.forward` is live (two-constant mixing → K/S → KM reflectance →
Saunderson → spectrum→colour). First pass found **AC-14 = B** (G5, secondary G4):
the opaque two-constant forward is **scale-invariant in the volume weights**
(`K/S = Σv·K / Σv·S` is unchanged by rescaling all volumes), so a non-normalizing
engine predicts the *same* colour as a normalizing one — the old AC-14 test, which
asserted only `forward(raw)==forward(normalized)` and the `6:3` scaling through the
colour surface, could not reject its named raw-weight impl (the grader built that
non-normalizing pipeline and got bit-identical XYZ). **Fixed in-phase (fix pass
1/3):** exposed `normalizeParts` on the public surface (`pigment_km.dart`) — the
spec step explicitly names "parts normalized to sum 1" as the observable — and
rewrote AC-14 to assert the normalization directly (Σ=1, {2/3,1/3}, ratio
preserved, `≠ raw 2.0`), which rejects the identity/non-normalizing map, while the
scale-invariance is kept as an honestly-labelled consistency property (not the
reject). A second fresh grader re-graded **AC-14 = A**. Result: **5 A** (AC-1, AC-3,
AC-4 re-confirmed; AC-5 re-confirmed now-live; AC-14 B→A).

| AC | Test | Grade | Notes |
|---|---|---|---|
| AC-1 | TestAC01_SpectrumToColour | A (re-confirmed) | Untouched by FORWARD-2. ΔE00 ≤ 1 to the D65 white point + Y≈1 + sRGB white; rejects dropped `yBarD65Sum`/mis-weighted illuminant. Unchanged single-white G5-floor flag. |
| AC-3 | TestAC03_KmRoundTrip | A (re-confirmed) | `reflectance.dart` untouched. R∞∈[0,1] per bin rejects the +√ branch; K/S=0→R=1 anchor; round-trip 1e-5. |
| AC-4 | TestAC04_Saunderson | A (re-confirmed) | `saunderson.dart` untouched. Independent full-formula `refMeasured` per bin for both media + hand anchor (0.12727273) + distinctness controls; pins the k2 term. G-5 lockstep flag unchanged. |
| AC-5 | TestAC05_TwoConstantMix | A | Now live through the real `forward`. Self-mix idempotence (0.3≡0.9≡pure, ΔE00<1e-6) + order-independence (ab≡ba, from `mixTwoConstant`'s Float64-accumulate-then-narrow) + Control 1 (mix ≠ each pure, >1) + Control 2 (25/75 ≠ 75/25 ≠ 50/50 — genuinely different K/S ratios, not a rescale). Rejects order-dependence, collapse-to-one-component, and a volume-ignoring mix. Non-vacuous; consistent with the prior hardened A. |
| AC-14 | TestAC14_Normalize | A | **B→A, fixed in-phase (fix pass 1/3).** Asserts the public `normalizeParts` observably — Σ=1, {2/3,1/3}, 2:1 ratio preserved, `≠ raw 2.0`, idempotent on an already-normalized input — which **rejects the identity (non-normalizing) impl** the colour-only surface cannot (the opaque forward is scale-invariant). The `forward(raw)==forward(normalized)==forward(6:3)` equalities are kept as an honestly-labelled scale-invariance consistency property (explicitly NOT the reject), plus a "different ratio → different colour" control rejecting a volume-ignoring engine. The engine genuinely routes through `normalizeParts` (forward.dart `forwardReflectance`). |

## Behaviour re-grade — COLOR-3 (un-pended AC-2; re-confirmed AC-1, AC-3, AC-4, AC-5, AC-14) · graded 2026-10-16

Grader: fresh independent adversarial subagent, G1–G6; given all prior grids and
asked to justify any downgrade against a named rule. COLOR-3 un-pends AC-2
(`gamutMap`) and, as a refactor, extracts the sRGB/OKLab/XYZ conversion maths out
of `spectrum_to_colour.dart` into `oklch.dart` (adding the inverse OKLCh→linear-
sRGB and linear-sRGB→XYZ the gamut mapper needs); AC-1 and AC-5/AC-14 now run
through the moved-but-equivalent code. Verified green at baseline
(`PIGMENT_KM_RUN_PENDING=true`): AC-1…AC-5 and AC-6 pass (+6); the real `gamutMap`
passes AC-2. Re-confirmations hold — the five carried-forward tests assert either
unchanged modules (KM/Saunderson/normalize) or **relative** colour comparisons
between `forward` outputs, which are robust to the extraction. **AC-2 downgraded to
B (G4, consequently G5):** I constructed a wrong `gamutMap` that passes every
assertion (see note). Initial result: **5 A, 1 B (AC-2)** — a genuine G-rule B
(NOT a sanctioned deferral), owed a fix this phase. Fixed in two in-phase passes:
fix pass 1 hardened the sRGB↔OKLCh consistency triple but left a ~0.006-chroma
window; fix pass 2 added the decisive UNCLAMPED-in-gamut check via a new
independent reference inverse (`oklchToLinearSrgb` in `colour_math.dart`),
re-graded **A** by a fresh grader. **Final: 6 A.** Fix passes 2/3.

Re-graded after the in-phase fix (fix pass 1): B — the new `srgbToOklch(mapped.srgb)` consistency triple closes the hidden-clip hole for large partial reductions but its 5e-3 tolerances are looser than the gamut precision, so a disguised hard-clip stopping ≤~0.006 chroma above the boundary (linear red ≈ −0.011 → clamped to 0) still passes while hard-clipping a channel (G4).

| AC | Test | Grade | Notes |
|---|---|---|---|
| AC-1 | TestAC01_SpectrumToColour | A (re-confirmed) | Code now imports `encodeGamma`/`xyzToLinearSrgb`/`linearSrgbToOklch` from `oklch.dart` but the pipeline (illuminant-weighted XYZ ÷ `yBarD65Sum` → sRGB → OKLCh) is byte-for-byte equivalent; test unchanged and green. Given checked through the public surface (spectrum length 31, published XYZ = D65 white, published sRGB = white); When runs real `spectrumToColour`; Then ΔE00 ≤ 1 vs the independent CIEDE2000 yardstick + Y≈1 + sRGB white. Rejects a dropped `yBarD65Sum`/mis-weighted illuminant. Unchanged single-white G5-floor flag (a non-white published target hardens it post DATA-5). |
| AC-2 | TestAC02_GamutMap | **A** | **Re-graded after the COLOR-3 author's in-phase fix.** The author added the recommended consistency triple: the independent `srgbToOklch(mapped.srgb)` must match `mapped.oklch` within L 5e-3 / hue 0.5° / chroma 5e-3. This **closes the hole for LARGE partial reductions** — the prior c=0.30 example now fails, because clamping its −0.158 red channel to 0 drops the re-derived chroma far below the reported 0.30. **But the 5e-3 tolerances are looser than the gamut-boundary precision, so a disguised hard-clip stopping just above the boundary still passes.** Constructed wrong impl: a chroma-reduction mapper with a loose in-gamut epsilon (or one that returns `hi`, or adds a small positive margin like `lo+0.004`) landing at c_p ∈ ≈[0.2202, 0.2257] (true boundary ≈0.2201). It is genuinely **out of gamut** — its OKLCh→linear red channel ≈ −0.011, **hard-clipped to 0 by `encodeGamma`** — yet the clamp perturbs the re-derived OKLCh by only ~2e-4 chroma / ~3e-4 L / ~0.1° hue, **all inside the new tolerances**, so every assertion (incl. the triple) passes. It fakes the match with a hard clip exactly as the spec's second Then forbids. (A too-few-step/loose-epsilon boundary search is a plausible way to land there; separately, an over-reducer with chroma *below* the boundary also passes but satisfies every stated Then.) **Reject still open:** a partial-chroma-reduction mapper stopping ≤~0.006 chroma above the boundary, relying on the gamma encoder's clamp to hide the hard-clipped channel. *Fix (for the owning phase): take the prior grader's *alternative* — assert the UNCLAMPED `oklchToLinearSrgb(mapped.oklch)` ∈ [0,1] at the impl's 1e-7 grain (admits no tolerance loophole) — or tighten the consistency tolerances well below the ~0.006-chroma window.* **Re-graded after fix pass 2: A — the new assertion converts the mapper's REPORTED `mapped.oklch` back through the independent harness inverse `oklchToLinearSrgb` (self-contained Ottosson constants, not the library export; verified the exact inverse of `srgbToOklch`'s OKLab maths, round-trip 2.6e-7) and requires every UNCLAMPED linear channel ∈ [−1e-6, 1+1e-6]; the binding red channel has slope dr/dc ≈ −2.02 at the boundary c*≈0.22010, so the old ~0.006-chroma survival window collapses to ~5e-7 chroma (red ≈ −1e-6, a sub-perceptual float-noise excess), decisively failing the named prior reject (lo+0.004 / loose-ε / returns-hi at c_p≈0.2202–0.2257, red≈−0.011 → red far below −1e-6), while the consistency triple + L/hue-preservation (0.02 L / 2° hue; the clip of the out-of-gamut original is (0,1,0) at L≈0.87/h≈142°) block reporting a fake in-gamut OKLCh over a clipped sRGB — so no forbidden out-of-gamut-with-hard-clip impl survives; an over-reducer (chroma below the boundary) still passes but is admissible under the AC wording (it maps inside gamut, L/hue preserved, chroma reduced, no clip — minimality is design-§2 guidance, not an AC Then).* |
| AC-3 | TestAC03_KmRoundTrip | A (re-confirmed) | KM physics (`reflectance.dart`) untouched by COLOR-3. R∞∈[0,1] per bin rejects the +√ branch; K/S=0→R=1 anchor; round-trip 1e-5 rejects a dropped f(R) constant. Green at baseline. |
| AC-4 | TestAC04_Saunderson | A (re-confirmed) | `saunderson.dart` untouched. Independent full-formula `refMeasured` per bin for both media + hand anchor (0.12727273) + distinctness controls; pins the k2 term. G-5 constant-lockstep flag unchanged. Green at baseline. |
| AC-5 | TestAC05_TwoConstantMix | A (re-confirmed) | `forward` calls the refactored `spectrumToColour`, but every assertion is a **relative** ΔE00 between `forward` outputs (self-mix idempotence 0.3≡0.9≡pure; order ab≡ba; mix≠each pure; 25/75≠75/25≠50/50), which is invariant to the colour-maths extraction. Rejects order-dependence, collapse-to-one-component, and a volume-ignoring mix. Green at baseline. |
| AC-14 | TestAC14_Normalize | A (re-confirmed) | `normalizeParts` and the two-constant mix are unaffected by the colour refactor; the forward equalities are relative ΔE00 comparisons. Asserts the public `normalizeParts` observably (Σ=1, {2/3,1/3}, ratio preserved, ≠ raw 2.0, idempotent) — rejects the identity/non-normalizing impl — with scale-invariance kept as a labelled consistency property + a different-ratio control. Verified green at baseline. |

## Behaviour re-grade — SOLVER-2 (un-pended AC-16; re-confirmed AC-1, AC-3, AC-4, AC-5, AC-14, AC-2) · graded 2026-10-16

Grader: fresh independent adversarial subagent, G1–G6; given all prior grids
(latest baseline: the COLOR-3 re-grade) and asked to justify any downgrade against
a named rule. SOLVER-2 un-pends **AC-16** by wiring `CustomKmEngine.inverse` to a
new `lib/src/engine/inverse.dart` (`solvePaletteConstrained` — subset enumeration
over the palette + a per-subset simplex-grid optimizer minimizing a new library
CIEDE2000 `deltaE2000Lab`/`deltaE2000Xyz`; recipes ordered by ΔE00, truncated to
`topK`; `outOfGamut` hardcoded `false` as a documented SOLVER-4 placeholder).
Confirmed the change set is surgical: `git diff HEAD` touches only
`lib/src/engine/inverse.dart` (new), one-line `inverse` wiring in
`custom_km_engine.dart`, an additive barrel `export … show deltaE2000Lab,
deltaE2000Xyz`, the pending-gate rows (AC-16 removed from `pending.dart`, added to
`unpendedACs`), and `engine_test.dart` unit tests — **no change to
`colour/`, `km/`, `forward.dart`, or any acceptance test / harness file**, so the
six carried-forward tests run byte-identical code and their prior-A reasoning holds
unchanged. Default run **+14 ~20 (14 pass, 20 skip), all pass** — AC-16 now
executes and passes, no longer skipped. Baseline `PIGMENT_KM_RUN_PENDING=true … -x
stretch` **+17 -15** (the 7 un-pended ACs + AC-6 pass; the 15 still-pending ACs fail
for the right reason on their precondition/`UnimplementedError`). AC-16 verified
non-vacuous and discriminating by a throwaway probe: run against the *full* 3-paint
dataset (the palette-ignoring wrong impl) the reddish target returns the excluded
`acrylic.naphthol_red` in the top-K recipe list (positions 3–4 of 5), so the
per-id membership loop fails it. **Result: 7 A.**

| AC | Test | Grade | Notes |
|---|---|---|---|
| AC-16 | TestAC16_PaletteOnly | **A** | **Un-pended this phase; genuinely A.** Given checked through the public surface — the constructed palette excludes `acrylic.naphthol_red` (`paletteIds` asserted `isNot(contains(excluded.id))`) and is non-empty. When goes through the real public `engine.inverse(target, palette, MixOptions())` (the free `solvePaletteConstrained` is **not** exported — the test can only reach it via the engine surface). Then asserts the AC's exact observable at grain: every id in every returned recipe's `parts.keys` ∈ `paletteIds`, guarded by `recipes isNotEmpty` (non-vacuous — the 2-paint constrained palette yields 3 recipes {blue},{white},{white,blue}, all within topK=5). **Rejects the named wrong impl** — a solver that ignores the palette arg and reaches into the full dataset: verified by probe that for this reddish target (0.78,0.33,0.33) the full-dataset solve returns red in the top-K, so the membership loop fails on it. One AC per test (G6): asserts nothing about ΔE00, ordering, count, or gamut, so the SOLVER-4 `outOfGamut=false` placeholder and the ungraded ranking/accuracy ACs do not leak in. No G-rule gap; no augmentation owed. |
| AC-1 | TestAC01_SpectrumToColour | A (re-confirmed) | COLOR/`spectrum_to_colour.dart` untouched by SOLVER-2 (diff touches only engine inverse + gate + unit tests). ΔE00 ≤ 1 to the D65 white point (independent CIEDE2000 yardstick) + Y≈1 + sRGB white; rejects a dropped `yBarD65Sum`/mis-weighted illuminant. Green at baseline. Unchanged single-white G5-floor flag (a non-white published target hardens it post DATA-5). |
| AC-2 | TestAC02_GamutMap | A (re-confirmed) | `gamutMap`/`oklch.dart`/`colour_math.dart` untouched. The COLOR-3 hardened form stands: unclamped `oklchToLinearSrgb(mapped.oklch)` ∈ [−1e-6, 1+1e-6] per channel (binding red slope ≈ −2.02 collapses the old ~0.006-chroma survival window to ~5e-7) + consistency triple + L/hue preservation; rejects the disguised hard-clip-just-above-boundary impl. Green at baseline. |
| AC-3 | TestAC03_KmRoundTrip | A (re-confirmed) | `km/reflectance.dart` untouched. R∞∈[0,1] per bin rejects the +√ branch; K/S=0→R=1 anchor; round-trip 1e-5 rejects a dropped f(R) constant. Green at baseline. |
| AC-4 | TestAC04_Saunderson | A (re-confirmed) | `km/saunderson.dart` untouched. Independent full-formula `refMeasured` per bin for both media + hand anchor (0.12727273) + distinctness controls; pins the k2 internal-reflection term. G-5 constant-lockstep flag unchanged. Green at baseline. |
| AC-5 | TestAC05_TwoConstantMix | A (re-confirmed) | `forward.dart`/`km/mixing.dart` untouched. Every assertion is a relative ΔE00 between `forward` outputs (self-mix idempotence 0.3≡0.9≡pure; order ab≡ba; mix≠each pure; 25/75≠75/25≠50/50), invariant to the inverse addition. Rejects order-dependence, collapse-to-one-component, and a volume-ignoring mix. Green at baseline. |
| AC-14 | TestAC14_Normalize | A (re-confirmed) | `normalizeParts` (`forward.dart`) untouched. Asserts the public `normalizeParts` observably (Σ=1, {2/3,1/3}, ratio preserved, ≠ raw 2.0, idempotent) — rejects the identity/non-normalizing impl the scale-invariant colour surface cannot — with scale-invariance kept as a labelled consistency property + a different-ratio control. Green at baseline. |

Result: 7 A.

## Behaviour re-grade — SOLVER-3 (un-pended AC-15; re-confirmed AC-1, AC-2, AC-3, AC-4, AC-5, AC-14, AC-16) · graded 2026-10-16

Grader: fresh independent adversarial subagent, G1–G6; given all prior grids and
asked to justify any downgrade against a named rule, and to rule explicitly on the
constructed-tie augmentation's discrimination. SOLVER-3's only lib change is
`lib/src/engine/inverse.dart` (the `_byDeltaThenFewerPaints` comparator + the sort
swap); no colour/km/forward/harness file touched. Initial pass: **7 A, 1 B (AC-15)**
— the first constructed-tie used 3 twins (7 candidates → Dart's *stable*
insertion-sort regime), so a no-tie-break ΔE00-only sort passed it too: the
augmentation did not discriminate (G5 / augmentation-discrimination rule). Fixed
in-phase (fix pass 1/3): raised to 6 twins → 56 bit-equal-ΔE00 candidates (above
Dart's 32-elem threshold → unstable quicksort), where only an explicit prefer-fewer
key yields a non-decreasing paint-count ranking. Discrimination verified by
reverting the comparator (both the acceptance and unit tie tests fail; restored →
pass). **Final: 8 A.**

| AC | Test | Grade | Notes |
|---|---|---|---|
| AC-15 | TestAC15_RankedPreferFewer (base + constructed tie) | **A** | **Un-pended this phase; B→A in-phase.** Base test non-vacuous (≥2 recipes; best-first ΔE00 monotonicity; membership; Σ1). Constructed-tie case: 6 identical-reflectance twins → 56 subsets each predicting a **bit-identical** colour (Float32-narrowing in `mixTwoConstant` swamps the ~1e-16 accumulation error → all ΔE00 `equals(tiedDelta)`), a genuine EXACT tie across 1…4-paint recipes. 56 > Dart's 32-elem insertion-sort threshold → unstable quicksort, so the non-decreasing paint-count ranking (`counts.first==1`, `counts.last==4`, monotone, last-2-paint before first-3-paint) **requires** the explicit prefer-fewer key — verified it FAILS the pre-phase ΔE00-only `sort` and passes `_byDeltaThenFewerPaints`. Rejects both the reversed (prefer-more) tie-break (`counts.last==4`) and the no-tie-break solver (unstable-sort reshuffle). One AC per test (G6). |
| AC-1 | TestAC01_SpectrumToColour | A (re-confirmed) | COLOR pipeline untouched by SOLVER-3. ΔE00 ≤ 1 to the D65 white point + Y≈1 + sRGB white; rejects dropped `yBarD65Sum`/mis-weighted illuminant. Unchanged single-white G5-floor flag. |
| AC-2 | TestAC02_GamutMap | A (re-confirmed) | `gamut_map.dart`/`oklch.dart` untouched. Unclamped `oklchToLinearSrgb(mapped.oklch)` ∈ [−1e-6, 1+1e-6] + consistency triple + L/hue preservation; rejects the disguised hard-clip. |
| AC-3 | TestAC03_KmRoundTrip | A (re-confirmed) | `km/reflectance.dart` untouched. R∞∈[0,1] rejects the +√ branch; K/S=0→R=1 anchor; round-trip 1e-5 rejects a dropped f(R) constant. |
| AC-4 | TestAC04_Saunderson | A (re-confirmed) | `km/saunderson.dart` untouched. Independent full-formula `refMeasured` per bin both media + hand anchor + distinctness controls; pins k2. |
| AC-5 | TestAC05_TwoConstantMix | A (re-confirmed) | `forward.dart`/`km/mixing.dart` untouched. Relative-ΔE00 self-mix idempotence + order-independence + volume controls. |
| AC-14 | TestAC14_Normalize | A (re-confirmed) | `normalizeParts` untouched. Σ=1, {2/3,1/3}, ratio preserved, ≠ raw 2.0, idempotent + different-ratio control. |
| AC-16 | TestAC16_PaletteOnly | A (re-confirmed) | inverse.dart's ranking changed, but AC-16 asserts only order-independent per-id membership with `recipes isNotEmpty`; the 2-paint palette yields 3 recipes ≤ topK (no truncation), so the comparator change cannot affect it. Rejects a full-dataset-reaching solver. |

Result: 8 A.

## Behaviour re-grade — SOLVER-4 (AC-18) · graded 2026-10-17

Grader: fresh independent adversarial subagent, G1–G6, given the prior grids and
asked to justify any downgrade against a named rule. SOLVER-4's only lib change is
`lib/src/engine/inverse.dart` (the target-level gamut gate + the `_flaggedOutOfGamut`
re-stamp); the pending/unit files and the AC-18 acceptance test are the other
changes — **no harness fixture, no colour/km/forward module touched.** The re-stamp
maps over `ranked` in order and carries `parts`/`colour`/`deltaE00`/`provenance`
through unchanged, so it cannot reorder, re-count or alter any neighbour's recipes.
**Result: 9 A, 0 B, 0 fixes owed (passed first run, fix 0/3).**

| AC | Test | Grade | Notes |
|---|---|---|---|
| AC-18 | TestAC18_OutOfGamut | **A** | **Un-pended this phase.** Given checked (`oogColour.oklch.c > 0.2`; fixture palette has no green primary). When via the real public `engine.inverse`. Then at grain: `best.outOfGamut isTrue` + `best.deltaE00 > gamutThreshold (5)` + (augmented in-phase, AC-18's own Then, G6-safe) `best.verdict` contains "out of gamut" → pins "never reports it as a match". Rejects the AC's named wrong impl (nearest mix unflagged) and the pre-phase hardcoded-`false` placeholder — both red at baseline. One AC per test (G6): asserts nothing about in-gamut non-flagging (AC-17's Then). |
| AC-1 | TestAC01_SpectrumToColour | A (re-confirmed) | COLOR pipeline not in inverse.dart's path. ΔE00 ≤ 1 to D65 white + Y≈1 + sRGB white. |
| AC-2 | TestAC02_GamutMap | A (re-confirmed) | `gamut_map.dart`/`oklch.dart`/`colour_math.dart` untouched. Unclamped round-trip + L/hue preservation; rejects the disguised hard clip. |
| AC-3 | TestAC03_KmRoundTrip | A (re-confirmed) | `km/reflectance.dart` untouched. R∞∈[0,1] rejects the +√ branch; K/S=0→R=1 anchor. |
| AC-4 | TestAC04_Saunderson | A (re-confirmed) | `km/saunderson.dart` untouched. Independent full-formula per bin + hand anchor + distinctness controls. |
| AC-5 | TestAC05_TwoConstantMix | A (re-confirmed) | `forward.dart`/`km/mixing.dart` untouched. Idempotence + order-independence + volume controls. |
| AC-14 | TestAC14_Normalize | A (re-confirmed) | `normalizeParts` untouched. Σ=1, {2/3,1/3}, ratio preserved, ≠ raw, idempotent + control. |
| AC-15 | TestAC15_RankedPreferFewer | A (re-confirmed) | Comparator untouched; the flag re-stamp preserves order/`deltaE00`/`parts.length`, so base + constructed-tie both hold. Verified passing in the run. |
| AC-16 | TestAC16_PaletteOnly | A (re-confirmed) | `_flaggedOutOfGamut` carries `parts` through, so the (possibly-flagged) reddish-target solve cannot change `parts.keys`; per-id membership holds. |

### AC-18 carried flags (no grade change)
- **AC-17/AC-18 pairing is one-sided until SOLVER-6.** AC-18 alone passes an "always-flag" impl; the in-gamut-non-flag reject lives in AC-17 (pending, SOLVER-6). The behaviour exists now (`if (ranked.first.deltaE00 <= gamutThreshold) return ranked;`), so the pairing closes when SOLVER-6 un-pends AC-17. Adding an in-gamut control inside AC-18 would reach AC-17's Then (G6) — the split is correct.
- **"honest ΔE00" asserted as `> 5` only,** not cross-checked against the independent yardstick `deltaE00(best.colour.xyz, target.xyz)`. Core intent (distance not understated) is covered; a yardstick cross-check (AC-18's own) would fully pin it — optional hardening.

Result: 9 A.

## Behaviour re-grade — SOLVER-5 (un-pended AC-19; re-confirmed AC-1, AC-2, AC-3, AC-4, AC-5, AC-14, AC-15, AC-16, AC-18) · graded 2026-10-17

Grader: fresh independent adversarial subagent, G1–G6, given the prior grids and
asked to justify any downgrade against a named rule. SOLVER-5's only lib change is
`lib/src/engine/inverse.dart` (partition the palette by `Medium`, search each group
independently, pool the candidates before the unchanged ranking/topK/out-of-gamut
gate); the comparator, gamut gate and subset/simplex machinery are untouched
(confirmed via `git diff`). Verified `dart analyze` clean; AC-19 passes default +
run-pending; the full engine+acceptance suite passes. The grader confirmed the
partition is behaviourally identical on single-medium palettes (one group = the
prior per-palette search), so every re-confirmed AC either exercises code outside
`inverse.dart` or runs on a single-medium palette. **Result: 10 A, 0 B, 0 fixes
owed (passed first run, fix 0/3).**

| AC | Test | Grade | Notes |
|---|---|---|---|
| AC-19 | TestAC19_CrossMedium (primary + control) | **A** | **Un-pended this phase.** Given checked through the public surface (`paletteMedia containsAll {acrylic, oil}`; palette via `PigmentTable.load`). Primary When via real `engine.inverse`; Then at grain — every recipe `media hasLength(1)` + `media.single == r.medium`, guarded by `recipes isNotEmpty`. **G5 rejects both wrong impls:** (1) the unpartitioned whole-palette solver — on the 6-paint mixed palette (maxPaints=4) it enumerates a size≥2 cross-medium subset and `forwardColour` THROWS (`forward.dart` cross-medium guard), so the When errors; this is exactly the pre-phase code, so AC-19 fails it by construction; (2) a `palette.first.medium`-only (acrylic) solver passes the primary but is caught by the **control**: `oilTarget = engine.forward({oil.yellow_ochre:1.0})` (oil is 2nd in the palette), and the control asserts `best.medium == Medium.oil`, `bestDist < 1.0` (the pure oil paint reproduces its own colour), and that acrylic-only lands strictly farther — a real temptation decisively failing a first-medium-only solver. Closes the ITEST-4 carry-forward control flag; honestly documents why a true cross-medium-blend target is impossible (forward refuses to span media). G6 clean. *Non-blocking note: the primary `media hasLength(1)` is near-tautological for any solver routed through the real forward (a cross-medium recipe can't be built without throwing); the genuine discrimination is the When-not-throwing + the control — both present, so A stands.* |
| AC-1 | TestAC01_SpectrumToColour | A (re-confirmed) | COLOR pipeline not in inverse.dart's path. ΔE00 ≤ 1 to D65 white + Y≈1 + sRGB white. Unaffected by the partition. |
| AC-2 | TestAC02_GamutMap | A (re-confirmed) | `gamut_map.dart`/`oklch.dart`/`colour_math.dart` untouched. Unclamped round-trip + consistency triple + L/hue preservation; rejects the disguised hard clip. |
| AC-3 | TestAC03_KmRoundTrip | A (re-confirmed) | `km/reflectance.dart` untouched. R∞∈[0,1] rejects the +√ branch; K/S=0→R=1 anchor; round-trip 1e-5. |
| AC-4 | TestAC04_Saunderson | A (re-confirmed) | `km/saunderson.dart` untouched. Full-formula `refMeasured` per bin both media + hand anchor (0.12727273) + distinctness controls; pins k2. |
| AC-5 | TestAC05_TwoConstantMix | A (re-confirmed) | `forward.dart`/`km/mixing.dart` untouched. Relative-ΔE00 self-mix idempotence + order-independence + volume controls. |
| AC-14 | TestAC14_Normalize | A (re-confirmed) | `normalizeParts` untouched. Σ=1, {2/3,1/3}, ratio preserved, ≠ raw 2.0, idempotent + different-ratio control. |
| AC-15 | TestAC15_RankedPreferFewer (base + constructed tie) | A (re-confirmed) | Comparator `_byDeltaThenFewerPaints` unchanged. Both palettes are single-medium (synthPigments all acrylic; 6 twins all `Medium.acrylic`) → the partition yields one group = identical candidate set (still 56 subsets for the tie, C(6,1..4)) and identical ordering to pre-phase. Verified passing. Cannot be weakened by the partition. |
| AC-16 | TestAC16_PaletteOnly | A (re-confirmed) | Single-medium acrylic palette → one group. Membership holds a fortiori under partition (each recipe drawn from one group ⊆ palette). Rejects a full-dataset-reaching solver. |
| AC-18 | TestAC18_OutOfGamut | A (re-confirmed) | synthPigments (acrylic) + oogColour → single group; the gamut gate still keys on `ranked.first` (pooling cannot change `ranked.first` for a single-medium palette). `outOfGamut isTrue` + `deltaE00 > 5` + verdict "out of gamut". |

Result: 10 A.
