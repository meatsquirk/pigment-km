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

## DATA-8 re-grade (shared-fixture hue fix, enabler) · graded 2026-10-17

Grader: fresh independent adversarial subagent, G1–G6, seeded with the bands
above. **Re-confirmed by a second independent adversarial subagent in the DATA-8
completion session (2026-10-17): identical verdict — 10 A, 0 downgrades, 0 fixes
owed; AC-16/AC-19 discrimination strengthened by the fix, AC-18 green still
out-of-gamut (best ΔE00 32.40), no stale/vacuous row.** DATA-8 inverted the synthetic fixture's `_chroma` K Gaussian (paints now
*reflect* at their named hue instead of absorbing it → rendering the complement)
and moved two peak bins (acrylic phthalo_blue 4→6, oil yellow_ochre 10→18). The
fixture is the shared helper every `synthPigments`-based AC renders against, so
every **un-pended** AC test (AC-1/2/3/4/5/14/15/16/18/19) was re-graded for
whether the hue rotation weakened its discrimination. `dart test` green (136
passed, 17 pending skipped). **Result: 10 A, 0 downgrades, 0 fixes owed.**

| AC | Test | Grade | Renders vs. fixture? | Justification (did the hue-fix change discrimination?) |
|---|---|---|---|---|
| AC-1 | TestAC01_SpectrumToColour | A | No — `perfectDiffuser`/D65 white | No pigment touched. |
| AC-2 | TestAC02_GamutMap | A | No — constructed OOG `ColourValue` | No pigment touched. |
| AC-3 | TestAC03_KmRoundTrip | A | Yes — reads blue K/S | New K/S∈[0.167,3.167], all >0 → Given holds; R∞∈[0,1]/anchor/round-trip are KM-math, hue-independent. |
| AC-4 | TestAC04_Saunderson | A | No — constructed ramp | Unchanged. |
| AC-5 | TestAC05_TwoConstantMix | A | Yes — white+blue forward | Coarse ΔE00 controls (mix vs pures 13.8/30.8 ≫1; 25/75≠75/25 16.4 ≫1) swamp the hue rotation; scale/order checks hue-independent. |
| AC-14 | TestAC14_Normalize | A | Yes (forward only) | Σ1 / ratio-preserved / rejects-identity are parts-map math; forward consistency + ratio control hue-independent. |
| AC-15 | TestAC15_RankedPreferFewer | A | Yes — grey solve | 5 ranked candidates, ΔE00 non-decreasing [0.75,11.9,14.8,18.2,19.3]; grey reachable old & new; constructed-tie companion uses fixture-independent twins. |
| AC-16 | TestAC16_PaletteOnly | A (strengthened) | Yes — reddish target, red excluded | Best uses only {white,blue}; excluded red never appears. Red now renders red (h≈28) → the reddish target is genuinely tempting (was its cyan complement before), so the dataset-reaching reject fires harder. |
| AC-18 | TestAC18_OutOfGamut | A | Yes — green vs white/blue/red | Green stays unreachable: best ΔE00 32.40 (≫5), `outOfGamut` true, verdict "out of gamut". No green primary at any hue assignment. |
| AC-19 | TestAC19_CrossMedium | A (strengthened) | Yes — oil yellow_ochre control | Best medium oil, bestDist≈0, acrylicBest 18.76; oil yellow now renders yellow (h≈86.6), genuinely unreachable by acrylic white/blue/red → sharper first-medium-only reject. |

Note: AC-17 (cool-blue in-gamut) remains **pending** (owner SOLVER-6) so it is
outside this un-pended re-grade; DATA-8 only makes its target reachable
(ΔE00 3.69 via white 0.917 + phthalo_blue 0.083, recorded for SOLVER-6).

## Behaviour re-grade — FORWARD-4 (un-pended AC-13; re-confirmed AC-1,2,3,4,5,14,15,16,18,19) · graded 2026-10-17

Grader: fresh independent adversarial subagent, G1–G6; given all prior grids and
asked to justify any downgrade against a named rule. FORWARD-4's only change is the
pending-gate rows (AC-13 moved from `pendingACs` to `unpendedACs`) plus an
empty-array-safety one-liner in `tool/coverage_gate.sh`; no `lib/` production code,
no acceptance-test body, no fixture touched (verified via `git diff HEAD`). AC-13's
forward engine was already live since FORWARD-2, so the test now simply runs.
`dart test test/acceptance` green (+19 ~16). AC-13's chroma gap measured by a
throwaway scratchpad probe. **Result: 11 A, 0 B, 0 fixes owed.**

| AC | Test | Grade | Notes |
|---|---|---|---|
| AC-13 | TestAC13_Desaturation | **A** | **Un-pended this phase; genuinely A.** Both Givens via public `forward` before the When (pureBlue c=0.092, pureRed c=0.078 both >0.04; Δh=113°>20°). Then `kmMix.oklch.c (0.01618) < srgbToOklch(sRGB-midpoint).c (0.04849)` — gap 0.0323, ratio 0.334 (≈3× desaturation), neither near zero → strict `<` non-vacuous and noise-free. **Rejects the RGB-space-blending engine**: library `linearSrgbToOklch` shares byte-identical Ottosson constants with the harness, so an sRGB-midpoint impl lands at exactly `rgbBlendChroma` → strict `<` false → fails; a collapse-to-component impl reports higher chroma → also fails. G6 clean (asserts only desaturation). Prior strict-`<` flag now quantified and discharged. |
| AC-1 | TestAC01_SpectrumToColour | A (re-confirmed) | COLOR pipeline not touched by FORWARD-4. ΔE00 ≤ 1 to D65 white point + Y≈1 + sRGB white; rejects dropped `yBarD65Sum`/mis-weighted illuminant. Unchanged single-white G5-floor flag. |
| AC-2 | TestAC02_GamutMap | A (re-confirmed) | `gamut_map.dart`/`oklch.dart`/`colour_math.dart` untouched. Unclamped `oklchToLinearSrgb(mapped.oklch)` ∈ [−1e-6,1+1e-6] + consistency triple + L/hue preservation; rejects the disguised hard-clip-just-above-boundary. |
| AC-3 | TestAC03_KmRoundTrip | A (re-confirmed) | `km/reflectance.dart` untouched. R∞∈[0,1] per bin rejects the +√ branch; K/S=0→R=1 anchor; round-trip 1e-5. |
| AC-4 | TestAC04_Saunderson | A (re-confirmed) | `km/saunderson.dart` untouched. Full-formula `refMeasured` per bin for both media + hand anchor (0.12727273) + distinctness controls; pins the k2 term. G-5 constant-lockstep flag unchanged. |
| AC-5 | TestAC05_TwoConstantMix | A (re-confirmed) | `forward.dart`/`km/mixing.dart` untouched. Relative-ΔE00 self-mix idempotence (0.3≡0.9≡pure) + order-independence (ab≡ba) + volume controls (mix≠pures; 25/75≠75/25≠50/50). |
| AC-14 | TestAC14_Normalize | A (re-confirmed) | `normalizeParts` untouched. Σ=1, {2/3,1/3}, 2:1 ratio preserved, ≠ raw 2.0, idempotent — rejects the identity/non-normalizing impl the scale-invariant colour surface cannot — plus a different-ratio control. |
| AC-15 | TestAC15_RankedPreferFewer (base + constructed tie) | A (re-confirmed) | Comparator `_byDeltaThenFewerPaints` untouched. Base: ≥2 recipes, best-first ΔE00 monotonic, membership, Σ1. Constructed tie: 6 identical-reflectance twins → 56 bit-equal-ΔE00 subsets > Dart's 32-elem threshold → unstable quicksort, so non-decreasing paint-count ranking requires the explicit prefer-fewer key. Fixture-independent twins. |
| AC-16 | TestAC16_PaletteOnly | A (re-confirmed) | inverse.dart untouched. Palette excludes `naphthol_red` (asserted absent) against a reddish target; every recipe paint ∈ palette. Post-DATA-8 the red renders red (h≈28°) so the temptation is genuine → dataset-reaching reject fires hard. |
| AC-18 | TestAC18_OutOfGamut | A (re-confirmed) | inverse.dart gamut gate untouched. Green (c>0.2, no green primary) → `outOfGamut isTrue` + `deltaE00 > 5` (best ≈32.40) + verdict contains "out of gamut". Rejects the nearest-mix-unflagged false recipe. |
| AC-19 | TestAC19_CrossMedium (primary + control) | A (re-confirmed) | inverse.dart partition untouched. Primary: every recipe `media hasLength(1)` + `media.single==r.medium` (a cross-medium subset throws in the forward guard). Control: oil-yellow target (oil 2nd in palette) → `best.medium==oil`, bestDist<1.0, acrylic-only lands farther → rejects a first-medium-only solver. |

Result: 11 A.

## Band 5 — DATA-2 (AC-8 un-pended; re-confirms AC-1,2,3,4,5,13,14,15,16,18,19) · graded 2026-10-17

Grader: fresh independent general-purpose subagent, adversarial, G1–G6. DATA-2's
change set verified surgical (`git diff`): only `lib/src/data/resample.dart`
(stub → real linear resampler), the two pending-gate files, `backends_stub_test.dart`
(resample stub row dropped), and new `test/resample_test.dart`. `resampleOntoCanonical`
is a brand-new standalone function called **only** by AC-8 and its unit test —
`PigmentTable`/fixtures generate directly on the canonical grid and never call it —
so the 11 carried ACs run byte-identical code to Band 4 (regression structurally
impossible). Default suite green (AC-8 live, 15 pending skip). **Result: 12 A, 0 B,
0 regressions.**

| AC | Test | Grade | Notes |
|---|---|---|---|
| AC-8 | TestAC08_Resample | **A** (G5 floor met) | **Un-pended this phase; genuinely A.** Given checked (native 380–730@10 asserted `hasLength(36)`; ramp derived). When via the real barrel export `resampleOntoCanonical`. Then at grain: `out hasLength(31)` + exact value at every canonical bin (`closeTo(ramp(nm),1e-5)`) + endpoints (400→0, 700→1). **Rejects the index-misplaced copy** (native[0]=380→slot 0 → −0.0667 ≫1e-5) and window/truncation errors. **G5-floor flag (not a B):** the AC native grid is 10 nm-aligned with the canonical grid, so every canonical bin coincides with a native sample (t≡0/1) — a nearest-neighbour/no-interpolation impl would pass identically, but it is **correct** for every in-scope dataset (acrylic 380–730, oil 400–700 are both 10 nm-aligned), so not a wrong impl for any contemplated input (AC-1 single-fixture precedent). The fractional-interpolation branch IS discriminated by the companion unit test `test/resample_test.dart` (offset grid `[380,420,500,620,730]`, canonical bins strictly between samples). *Optional hardening (not owed): an offset-grid control inside AC-8.* G6 clean. |
| AC-1..AC-5, AC-13, AC-14, AC-15, AC-16, AC-18, AC-19 | (as Band 4) | A (re-confirmed) | Byte-identical code to Band 4 — resample.dart is isolated and in no other AC test's path (verified by diff scope + grep + green suite). No grade regressed. |

Result: 12 A.

## Behaviour re-grade — DATA-3 (un-pended AC-6) · graded 2026-10-18

**13 A, 0 downgrades.** Fresh adversarial subagent (G1–G6 + catalogue), given the prior grid and asked to justify any downgrade against a named rule. Default suite green (148 passed); run-pending red baseline correct (the 14 still-pending ACs run, 12 fail for the right reason, AC-17/20 green-at-baseline); all 13 un-pended ACs pass in the default run and none appear in the run-pending failing set. **No regressions** — the file-sourced palette is byte-identical to the prior in-memory fixture (the `shipped synthetic asset parity (no drift)` test enforces on-disk bytes == `encode(SyntheticFixture.artifact(medium))`+"\n", and Pigment `==` deep-compares K/S), so every AC taking its palette via `synthPigments()` (AC-5/13/14/15/16/18/19) sees unchanged values.

| AC | Test | Grade | Justification |
|---|---|---|---|
| AC-6 | TestAC06_Artifact | **A** (was green-at-baseline) | **Load-from-asset now genuinely exercised:** `PigmentTable.load` reads+decodes `File(assetPathFor(medium))` (throws `FileSystemException`/`FormatException` on a missing/malformed file). The test independently `decode`s the asset and asserts `table.pigments[i] == decoded.pigments[i]` for every paint (Pigment `==` deep-compares K/S via `spectraEqual` + medium/provenance/sourceRef/opacity/pigmentIndex), plus per-field Thens (K/S length 31 + finite, pigmentIndex non-empty, opacity∈[0,1], provenance∈enum, `p.medium==medium`). Rejects a loader that drops K/S, leaves provenance null, mistags medium, or uses a wrong grid length. The one wrong loader no value-based assertion can separate — "rebuilds identical data in memory instead of reading the file" — is byte-indistinguishable by construction (parity test); the file-source guarantee is independently pinned by that parity test + load's throw-on-missing/malformed contract. |
| AC-1..AC-5, AC-8, AC-13, AC-14, AC-15, AC-16, AC-18, AC-19 | (as prior bands) | A (re-confirmed) | DATA-3 touched only `pigment_table.dart` (the load path). Palettes via `synthPigments()` are now file-sourced but byte-identical (parity test). No grade regressed. |

Result: 13 A.

## Behaviour re-grade — DATA-4 (un-pended AC-10) · graded 2026-10-18

**14 A, 0 downgrades, 0 fixes.** Fresh adversarial subagent (G1–G6 + catalogue), given the prior grid and asked to justify any downgrade against a named rule. Default suite green (156 passed / 13 pending-skipped); run-pending red baseline correct — AC-10 now runs un-skipped and passes, the 11 still-pending later-phase ACs fail for the right reason (AC-17/19/20 green-at-baseline). **No regressions** — DATA-4's only product, `masstone_tint.dart` (`deriveKsFromMasstoneTint` + the `Tint` typedef), is a standalone function whose sole callers are AC-10's test and the new non-AC unit test (`git grep` evidence below), so no carried AC's code path changed.

| AC | Test | Grade | Justification |
|---|---|---|---|
| AC-10 | TestAC10_MasstoneTint | **A** (un-pended this phase) | Builds a masstone (c=1) + 3 tints (c=0.25/0.5/0.75) from a KNOWN (trueK=gaussian bump bin14, trueS=0.3) and a known white (whiteK=0.05, whiteS=1.0) via the test's OWN independent opaque-KM reference `_tintReflectance`, calls `deriveKsFromMasstoneTint`, then re-predicts every tint AND the masstone through the SAME reference with the SAME white and asserts `closeTo(measured, 1e-3)` at all 31 bins. A genuine unique-solution constraint: per bin the reproduce-equality reduces to `(S′−S)·(r_m·Sw − Kw)=0`, so whenever the white's K/S ≠ the pigment's, the masstone (fixing K′/S′=r_m) plus even one tint forces S′=S, hence K′=K; 3 tints × 31 bins over-determines it (`r_m·Sw − Kw ≥ ~0.117` here → non-singular everywhere). **G5:** a masstone-only/ratio-only fit mispredicts the white-diluted tints by ~0.05 reflectance (≫1e-3) and fails; an impl ignoring the white's (Kw,Sw) collapses the tint RHS → degenerates to ratio-only → same failure. **G1:** structural Givens (≥2 tints, each fraction∈(0,1), spectra length 31) checked through the public surface before the When. **G2:** build and check use the independent reference, never the library's KM, so only the derivation is exercised. **G4:** Thens loop every tint × every bin at the raw-reflectance grain, exact 1e-3. **G6:** AC-10 only. No wrong implementation passes. |
| AC-1..AC-6, AC-8, AC-13, AC-14, AC-15, AC-16, AC-18, AC-19 | (as prior bands) | A (re-confirmed) | Isolation verified: `git grep deriveKsFromMasstoneTint\|masstone_tint` → only the barrel export, `masstone_tint.dart`, and AC-10's test; `git grep \bTint\b` outside the masstone files → only AC-10's test. pending.dart lost exactly the AC-10 row; pending_gate_test gained exactly AC-10→DATA-4; the deleted `backends_stub_test.dart` held only an implemented stub. Full regression green → no behavioural regression. No grade regressed. |

Result: 14 A.

## Behaviour re-grade — SOLVER-6 (un-pended AC-17; re-confirmed AC-1..AC-6, AC-8, AC-10, AC-13, AC-14, AC-15, AC-16, AC-18, AC-19) · graded 2026-10-18

**15 A, 0 downgrades, 0 fixes.** Fresh independent adversarial grader (G1–G6), given the prior grid and asked to justify any downgrade against a named rule. SOLVER-6's only product is a tighter per-subset optimizer: after the coarse 1/12 simplex grid, `_bestRecipeForSubset` runs 3 refinement rounds, each shrinking the step ×4 (1/12 → 1/768) and hill-climbing by shifting `step` of volume between two paints while keeping Σ=1 and every share in (0,1), accepting a move only on a > 1e-12 ΔE00 improvement. `git diff efb8fdf -- lib` confirms this is the sole lib change — the ranking key, out-of-gamut gate, medium partition, subset enumeration and membership checks are byte-identical to DATA-4, so no carried AC's observable behaviour changed. Default suite green (160 passed / 12 later-phase skipped); AC-17 runs un-skipped in both the default and the red-baseline (`PIGMENT_KM_RUN_PENDING=true`) runs, and at baseline only the 9 genuinely-pending ACs (AC-7, AC-9, AC-11, AC-12, AC-21..AC-25) fail, for the right reason — no un-pended AC regressed. The refinement only tightens a per-subset fit; on identical-reflectance twins (AC-15) no move ever improves so the coarse node stands and the 56-way exact tie is preserved, and on an unreachable target (AC-18) the nearest approach still exceeds the ceiling, so both pass unchanged.

Discrimination verified independently (grader reconstructed a coarse-grid-only optimizer over all acrylic subsets): for the augmentation target `forward({white:0.975, blue:0.025})` the coarse-grid-only whole-engine best = **6.39 ΔE00 (> 5 → FAILS)**, SOLVER-6 refined = **0.048**. (The ≈7.3 figure the author first cited was the white+blue subset alone; the whole-engine coarse best — pure white is a closer coarse node — is ≈6.4. Author corrected the comments to ≈6.4; both exceed 5, so the discrimination holds either way.)

| AC | Test | Grade | Justification |
|---|---|---|---|
| AC-17 | TestAC17_InGamut (base + SOLVER-6 augmentation) | **A** (un-pended this phase) | **Base case** (`synthPigments()` palette, target `colourFromSrgb((0.72,0.76,0.86))` via the independent reference): Given checked through the public surface before the When (`recipes isNotEmpty`), When `engine.inverse(...)`, Then at the raw grain the spec names — `best.deltaE00 <= opts.gamutThreshold` (5, the spec's own SI-NFR bound, not a fabricated stricter one) and `best.outOfGamut isFalse`. **Augmentation (strengthens only AC-17):** builds `reachableTarget = engine.forward({white:0.975, blue:0.025})` — legitimate G2, because the target is just a colour value reachable *by construction*; the solver must then independently re-derive a recipe and independently agree it is in gamut (the test writes no solver state). This target sits between the 1/12 coarse node and pure white, so a coarse-grid-only optimizer lands > 5 ΔE00 away and **fails** the `<= 5` assertion — **verified independently: coarse-only = 6.39, refined = 0.048** (G5 discrimination is real; the base case alone does not discriminate refinement since its coarse best is 3.69 < 5). Same `opts.gamutThreshold` (5) reused, no stricter bound. **G3:** the negative `outOfGamut isFalse` Then is paired at suite level with AC-18, where the identical solver flips the flag to `true` on an unreachable target, so it is non-vacuous. G1/G4/G6 clean (one AC, raw-ΔE00 grain, Givens public). No wrong implementation that stops early above 5 or skips refinement survives. |
| AC-1..AC-6, AC-8, AC-10, AC-13, AC-14 | (as prior bands) | A (re-confirmed) | COLOR/KM/DATA/FORWARD ACs — their code paths are untouched by SOLVER-6 (the only lib change is `_bestRecipeForSubset`). Byte-identical to the DATA-4 grid; all green in the full run. No grade regressed. |
| AC-15 | TestAC15_RankedPreferFewer (base + constructed tie) | A (re-confirmed) | Comparator `_byDeltaThenFewerPaints` untouched. On the 6 identical-reflectance twins every mixture predicts the same colour, so refinement never fires (no move beats eps) and the 56 bit-equal-ΔE00 subsets (> Dart's 32-elem threshold → unstable quicksort) still require the explicit prefer-fewer key for the non-decreasing paint-count ranking. Passes un-skipped. |
| AC-16 | TestAC16_PaletteOnly | A (re-confirmed) | Membership logic (subset enumeration from the declared palette) untouched; refinement only moves volume *among a subset's own paints*, never introduces a non-palette id. Reddish target with `naphthol_red` excluded — every recipe paint ∈ palette. |
| AC-18 | TestAC18_OutOfGamut | A (re-confirmed) | The target-level out-of-gamut gate in `solvePaletteConstrained` is unchanged. Refinement can only lower the nearest approach's ΔE00, but on the unreachable saturated-green target it stays well above 5, so `outOfGamut isTrue` + `deltaE00 > 5` + verdict "out of gamut" all still hold. |
| AC-19 | TestAC19_CrossMedium (primary + control) | A (re-confirmed) | The `byMedium` partition and per-group search are untouched; refinement runs strictly within one medium's subset. Every recipe stays single-medium and the oil-target control still selects the oil group. |

Result: 15 A.

## Behaviour re-grade — SOLVER-7 (un-pended AC-20; re-confirmed AC-1..AC-6, AC-8, AC-10, AC-13, AC-14, AC-15, AC-16, AC-17, AC-18, AC-19) · graded 2026-10-18

**16 A, 0 downgrades, 0 fixes.** Fresh independent adversarial grader (G1–G6), given the prior grid and asked to justify any downgrade against a named rule. SOLVER-7 is a pure performance optimization that un-pends **AC-20** (the SI performance budget). Its lib diff vs BASE `7991fe4` is exactly two files (`git --no-pager diff 7991fe47dd2acdecccc24fd656f949aef98641a5 -- lib` → `forward.dart` +101, `inverse.dart` +53/−9) with two products: (1) a new `BoundForward` class in `forward.dart` that reads a single-medium subset's K/S spectra and the medium's Saunderson config **once** in its factory, then `colourFor(shares)` predicts any share vector reusing internal `Float64List`/`Float32List` buffers — normalise→accumulate K,S in double→narrow to Float32→`kmReflectance`→`saundersonToMeasured`→`spectrumToColour`, the same arithmetic in the same paint order as `forwardColour`/`mixTwoConstant`; and (2) `_effectiveMaxPaints(groupSize, requested)` in `inverse.dart`, which replaces `math.min(opts.maxPaints, group.length)` with the largest per-recipe `k` whose cumulative `Σ C(groupSize, j)` for j=1..k stays within `_subsetBudget = 2500`, and `_bestRecipeForSubset` now evaluates grid+refinement points through a `BoundForward` instead of re-resolving ids per call. Nothing else changed: the ranking key, out-of-gamut gate, medium partition, subset enumeration and simplex/refinement geometry are byte-identical to SOLVER-6.

No carried AC regressed because the optimization is observationally transparent. (a) The precompute's bit-identical claim is pinned by `test/engine_test.dart` group "performance guard + precompute (SOLVER-7)", whose `BoundForward reproduces forwardColour bit-for-bit` test asserts **exact** equality — `expect(got.xyz.x, ref.xyz.x)` (and .y, .z) with **no tolerance** — across every subset size 1..3 and 8 random share vectors; it passes. So every grid/refinement evaluation in the ranking/accuracy ACs returns the identical colour it did at BASE. (b) The cap is transparent to every other AC because they all search small groups: the acrylic synthetic table (`synthPigments()` = `PigmentTable.load(Medium.acrylic)`) has exactly **3** pigments (titanium_white, phthalo_blue, naphthol_red), and the default `maxPaints` is 4. `_effectiveMaxPaints(3,4)` = 3 (15,120,575... never breaks; equals old `min(4,3)=3`) and for any ≤4-cap small group it equals the old `min`, so the enumerated subsets — and therefore the ranked recipes — of AC-15/16/17/18/19 are unchanged. AC-19's oil/acrylic groups are each ≤3 paints, same result. Only AC-20's 15-paint palette (and the SOLVER-7 unit tests) ever reaches the regime where the cap bites. Default acceptance run is green (`dart test test/acceptance` → 24 passed / 11 skipped); the 11 skips are exactly the 11 still-pending ACs in `pendingACs` (AC-7, AC-9, AC-11, AC-12, AC-21..AC-27). AC-20 is **not** in `pendingACs`, so `ac('AC-20')` returns null and the test runs **un-skipped** in the default run.

**AC-20 discrimination verified independently.** The spec Given is "a declared palette of about 15 paints"; the test (`test/acceptance/ac19_27_test.dart`) checks it through the public surface before the When (`expect(palette.length, 15)`), times `engine.inverse(target, palette, opts)`, and asserts elapsed `<= 2 s` — the raw wall-clock observable at the upper bound of the spec's stated 1–2 s range (G4). The **base** solve uses default `maxPaints=4` → `_effectiveMaxPaints(15,4)=4` → `Σ C(15,k) k=1..4 = 15+105+455+1365 = 1940` subsets, which is already in budget even without the guard, so the base case alone does **not** discriminate the guard. The author therefore added the SOLVER-7 **augmentation**: a `maxPaints: 8` solve that must also finish `<= 2 s`. Without the guard, `maxK = math.min(8, 15) = 8` (the diff's `-` line) enumerates `Σ C(15,k) k=1..8 = 15+105+455+1365+3003+5005+6435+6435 = 22818` subsets (matches the figure pinned in the unit-test comment), each running a coarse 1/12 simplex grid plus 3 refinement rounds — far beyond 2 s (phase measurements: maxPaints=5 → 2594 ms already over budget, maxPaints=6 → 8708 ms; maxPaints=8 is strictly larger). With the guard, `_effectiveMaxPaints(15,8)` adds subset counts 15,120,575,1940 then would hit 4943 at k=5 (> 2500) and **breaks → maxK=4** → 1940 subsets → ≈310 ms post-phase. So a 2 s ceiling sits with wide margin between the capped (~0.31 s) and uncapped (≫2 s) regimes, and the augmentation fails the one plausible wrong implementation the base cannot — an uncapped exponential search (G5). This is reinforced at unit level by `a high maxPaints over a large palette is capped…` which proves the capped and `maxPaints=8` solves return the **same** top-3 recipes and deltaE00 (the cap bounds work without changing results) and every returned recipe has `parts.length <= 4`.

| AC | Test | Grade | Justification |
|---|---|---|---|
| AC-20 | TestAC20_Performance (base + SOLVER-7 maxPaints=8 augmentation) | **A** (un-pended this phase) | **G1:** the Given "about 15 paints" is verified through the public input before the When (`expect(palette.length, 15)`). **G2:** the fast return comes from the real 15-paint palette passed to `engine.inverse` — the solver does the work; nothing is faked. **G4:** asserts the raw observable (`Stopwatch` elapsed) at the spec's named grain/value — `<= 2 s`, the top of the "about 1 to 2 seconds" range — plus `recipes isNotEmpty` and `length <= 3` (topK=3). **G5:** the base `maxPaints=4` solve (1940 subsets) is in budget regardless of the guard, so the **augmentation** supplies the discriminating control: `maxPaints=8` → without the guard `min(8,15)=8` → 22818 subsets → ≫2 s (≈8.7 s+ measured); with the guard capped to 4 → ≈0.31 s. The 2 s ceiling cleanly separates the two regimes, so the test fails an uncapped exponential solver. **G6:** one AC — both the base and augmentation assert only timing/count, nothing from another AC's surface. Timing is machine-dependent but the discrimination margin (0.31 s vs ≫2 s) is far wider than any plausible host variance. |
| AC-1..AC-6, AC-8, AC-10, AC-13, AC-14 | (as prior bands) | A (re-confirmed) | COLOR/KM/DATA/FORWARD ACs. Their forward evaluations now flow through `BoundForward` inside the solver, but the unit test pins `BoundForward.colourFor` ≡ `forwardColour` bit-for-bit (exact equality, no tolerance), and `forwardColour`/`forwardReflectance` themselves are unchanged — so every colour, ratio, provenance and gamut reading is identical to the SOLVER-6 grid. All green in the full run; no grade regressed. |
| AC-15 | TestAC15_RankedPreferFewer (base + 6 identical-reflectance twins) | A (re-confirmed) | Comparator `_byDeltaThenFewerPaints` untouched. The 6-twin palette is single-medium and small, so `_effectiveMaxPaints` returns the old `min` value — identical subsets enumerated — and the 56 bit-equal-ΔE00 subsets (> Dart's 32-elem stable-sort threshold → unstable quicksort) still require the explicit prefer-fewer key. BoundForward is bit-identical so the ties remain exact. Passes un-skipped. |
| AC-16 | TestAC16_PaletteOnly | A (re-confirmed) | Membership logic untouched; the 3-paint acrylic group at default cap enumerates the same subsets, and BoundForward only mixes a subset's own bound paints — no non-palette id can appear. Reddish target with `naphthol_red` excluded still yields palette-only recipes. |
| AC-17 | TestAC17_InGamut (base + reachable-by-construction augmentation) | A (re-confirmed) | 3-paint `synthPigments()` group → `_effectiveMaxPaints(3,4)=3`, same subsets as before; refinement geometry byte-identical and evaluated bit-for-bit via BoundForward, so the `white:0.975, blue:0.025` reachable target still solves to ≈0.048 ΔE00 ≤ 5 and `outOfGamut isFalse`. No change. |
| AC-18 | TestAC18_OutOfGamut | A (re-confirmed) | Target-level out-of-gamut gate unchanged; same subsets, bit-identical evaluations. The unreachable saturated-green target still exceeds 5 ΔE00 → `outOfGamut isTrue` + verdict "out of gamut". This is the paired G3 control for AC-17's negative Then. |
| AC-19 | TestAC19_CrossMedium (primary + oil-target control) | A (re-confirmed) | `byMedium` partition untouched; `_effectiveMaxPaints` is applied per medium group (each ≤3 paints → equals old `min`), and `BoundForward`'s factory re-asserts single-medium membership (throws on a mixed subset), reinforcing the constraint. Every recipe single-medium; the oil-target control still selects the oil group. |

Result: 16 A.

## Behaviour re-grade — TUNE-2 (un-pended AC-22; re-confirmed AC-1..AC-6, AC-8, AC-10, AC-13..AC-20) · graded 2026-10-18

**17 A, 0 B, 0 downgrades.** Fresh independent adversarial grader (G1–G6), given the prior grid and asked to justify any downgrade against a named rule. Verified empirically: `dart test test/acceptance` = 26 pass / 10 skip (the 10 still-pending ACs); both AC-22 tests pass; AC-15 (base+constructed) and AC-17 pass with the chroma penalty now default-ON. TUNE-2 un-pends **AC-22** (the natural-colour chroma-penalty tie-break). Its lib diff vs BASE `b0de35f` is the new `lib/src/tune/chroma_penalty.dart` (`naturalChromaPenalty = 1e-6`; `chromaPenalizedCost(recipe, λ) = ΔE00 + λ·C*`) plus `inverse.dart`: the ranking key is now `_byCostThenFewerPaints` (sort by `chromaPenalizedCost(·, λ)` with `λ = opts.chromaPenalty ? 1e-6 : 0`, then fewer paints), and the out-of-gamut verdict now reads the true ΔE00 **minimum** over all candidates (penalty-independent `bestDelta`) rather than `ranked.first.deltaE00`.

No carried AC regressed because the penalty is observationally transparent. The `λ = 1e-6` nudge reorders only recipes whose ΔE00 differ by less than `λ·C*` (< ~1e-6, with OKLCh chroma < 1) — i.e. genuine near-ties — and no un-pended AC's `.first`/monotonicity assertion sits on such a near-tie: AC-15's fixture has adjacent ΔE00 gaps ≫ 1e-6 (so `penalized == ΔE00` order, monotonicity holds) and its 56-twin constructed tie shares one colour → one chroma → uniform `λ·C*` → the exact tie and the prefer-fewer key survive; AC-17/18/19's `.first` recipes are distinctly separated or the gamut flag now reads the true penalty-independent minimum. AC-20 timing is unaffected (per-candidate cost is one add+mul).

**AC-22 discrimination (primary focus) — genuine and decisive, grade A.** The constructed-tie test builds two groups of identical-reflectance twins in one medium (a 2-paint VIVID group, a 3-paint MUTED group), each predicting one colour at any ratio, and bisects (100 iters) a target equidistant in ΔE00 between the two colours, nudged to the vivid side. It checks at recipe grain (G1/G4): the tie `|plain[vivid].deltaE00 − plain[muted].deltaE00| < 1e-9`, the strict chroma gap `cVivid > cMuted` (> 0.02), and `parts.length` 2 vs 3. **The discrimination from the AC-15 fewer-paints rule is the key point:** the muted recipe uses MORE paints, so penalty-ON ranking it first (`mutedPen < vividPen`) is something a "prefer fewer paints" rule alone cannot produce (it would keep the 2-paint vivid ahead). Driven purely by `MixOptions.chromaPenalty` (`plain`/`penalised` differ only in that flag — G2). Rejects a no-effect penalty (penalty-off gives `vividPlain < mutedPlain`; if the flag were ignored penalty-on would too, failing `mutedPen < vividPen`), a wrong-sign penalty, and the fewer-paints masquerade (G5). Base test's old hard `expect(sawTie, isTrue)` relaxed to a soft natural-tie sweep + the live penalty-OFF ΔE00-monotonicity check — the AC-15 base/constructed split precedent; the decisive discrimination is fully in the constructed test. One AC only, no leakage (G6). Resolves the ITEST-4 carry-forward "over-constrained on sawTie" flag.

| AC | Test | Grade | Justification |
|---|---|---|---|
| AC-22 | TestAC22_ChromaPenalty (base + constructed tie) | **A** (un-pended this phase) | See detail above. Discriminates the chroma penalty from the AC-15 fewer-paints tie-break via a 3-paint muted vs 2-paint vivid guaranteed ΔE00 tie; driven by `MixOptions.chromaPenalty` (G2); rejects no-effect/wrong-sign/fewer-paints-masquerade (G5); one AC (G6); givens checked at grain (G1/G4). Not flaky (bisection drives `0 < dMuted−dVivid < 1e-9`). |
| AC-1..AC-6, AC-8, AC-10, AC-13, AC-14 | (as prior bands) | A (re-confirmed) | COLOR/KM/DATA/FORWARD ACs — not on the inverse ranking path; untouched. |
| AC-15 | TestAC15_RankedPreferFewer (base + 6 twins) | A (re-confirmed) | Base monotonicity holds (fixture ΔE00 gaps ≫ 1e-6 ≫ λ·C*); 56-twin tie: one colour → one chroma → uniform penalty → exact tie preserved, prefer-fewer key still decides. |
| AC-16 | TestAC16_PaletteOnly | A (re-confirmed) | Membership logic untouched; the penalty cannot introduce a non-palette id. |
| AC-17 | TestAC17_InGamut (base + reachable aug) | A (re-confirmed) | `.first` may swap only among recipes within <1e-6 ΔE00 (still ≤5); the out-of-gamut flag now reads the true (penalty-independent) ΔE00 minimum, so the verdict is unchanged. |
| AC-18 | TestAC18_OutOfGamut | A (re-confirmed) | `.first.deltaE00 > 5` holds a fortiori (all ≥ true min > 5); flag reads the true min. |
| AC-19 | TestAC19_CrossMedium (primary + control) | A (re-confirmed) | Single-medium recipes; the oil-target control `.first` (ΔE00≈0) is distinctly separated, so the penalty cannot swap it. |
| AC-20 | TestAC20_Performance (base + aug) | A (re-confirmed) | Timing/count only; the per-candidate `λ·C*` cost is negligible. |

Result: 17 A.

## Behaviour re-grade — TUNE-4 (un-pended AC-23; re-confirmed AC-1..AC-6, AC-8, AC-10, AC-13..AC-22) · graded 2026-10-19

**18 A, 0 B, 0 downgrades, 0 fixes.** Fresh independent adversarial grader (G1–G6), given the prior TUNE-2 grid and asked to justify any downgrade against a named rule. TUNE-4 un-pends **AC-23** (the wet/dry toggle). Its lib diff vs BASE `da7cdb4` is three files: the NEW `lib/src/tune/wet_dry.dart` (`toDryState(recipe, transform)` re-renders a recipe's colour via `driedColour`, which adds the transform's CIE L*C*h deltas and rebuilds a consistent sRGB/XYZ/OKLCh triple — identity transform returns the recipe untouched); `saunderson.dart` (acrylic `MediumConfig.wetDry = WetDryTransform(lightnessDelta:-3, chromaDelta:1.5, hueDeltaDeg:3)`, oil = `WetDryTransform.none` gated on its dataset); and `custom_km_engine.dart`, whose `inverse` now reads `opts.wet` — when true it returns the solved list unchanged (`if (opts.wet) return recipes;`), when false it maps each recipe through `toDryState(recipe, configForMedium(recipe.medium).wetDry)` leaving parts/ΔE00/provenance/gamut/verdict untouched and only re-rendering the colour.

**No carried AC regressed** because the transform is observationally inert on the default path. The dry branch fires only when `opts.wet == false`, and in the whole acceptance suite only AC-23 passes `wet: false` (every other AC uses `const MixOptions()` = wet:true), so the engine early-returns the identical BASE recipe list — colours byte-identical to the TUNE-2 grid. The only other lib touch is the new `wetDry` field on `MediumConfig`; the `k1/k2` values that drive the Saunderson correction (AC-4 etc.) are unchanged, so no colour/ratio/gamut/provenance reading on any carried path moves. Confirmed empirically: `dart test test/acceptance` → **27 pass / 9 skip** (the 9 skips are exactly the 9 genuinely-pending ACs; AC-23 runs un-skipped), `--name "AC-23"` → pass.

**AC-23 discrimination — genuine and decisive, grade A.** The test solves the same acrylic target+palette twice (`wet:true`, `wet:false`) and, through the public surface, rejects every plausible wrong implementation: a no-op / flag-ignored engine (rejected by `deltaE00(dryBest.colour.xyz, wetBest.colour.xyz) > 0.5`, measured with the harness's own independent CIEDE2000, not the library metric); a re-solve instead of a state transform (rejected by `dryBest.parts closeTo wetBest.parts` within 1e-9, paired with the ΔE00>0.5 colour-change control — a clean G3 state-transform-not-re-solve discrimination); a zero/identity transform shipped (rejected by `expect(wetDry, isNot(WetDryTransform.none))`, where `wetDry` reads the **production** `configForMedium(Medium.acrylic).wetDry`); and a wrong-direction (brighter) transform (rejected by `dryBest.colour.xyz.y < wetBest.colour.xyz.y` at the Y/luminance grain the spec names — L* alone sets Y, so this is a true darkness test). The direction Thens are guarded on the production offset being non-zero (so they read config rather than hardcoding the expectation); production ships `-3/+3°` so both fire, and a zero-offset impl is caught earlier at `isNot(none)`. Asserting direction + a measurable ΔE00 (not the exact `-3/1.5/3` literals) matches the scenario's qualitative Then; the literals are explicitly non-authoritative defaults pending the G-5 dataset. One AC only (G6).

| AC | Test | Grade | Justification |
|---|---|---|---|
| AC-23 | TestAC23_WetDry | **A** (un-pended this phase) | Solves acrylic target wet vs dry. **G1:** `wet`/`dry` isNotEmpty and `wetDry isNot WetDryTransform.none` (production value) asserted before the Thens. **G2:** colour shift produced by the real engine reading real `configForMedium(...).wetDry`; no fake. **G3:** parts-equality (1e-9) paired with the ΔE00>0.5 colour-change control → state-transform-not-re-solve. **G4:** "darker" at the Y/luminance grain, hue-shift via independent `hueDiffDeg`, ΔE00 via the harness's own CIEDE2000. **G5:** rejects no-op (ΔE00>0.5), re-solve (parts closeTo), identity transform (isNot none), wrong-direction (`y` lessThan). **G6:** one AC. |
| AC-1..AC-6, AC-8, AC-10, AC-13, AC-14 | (as prior bands) | A (re-confirmed) | COLOR/KM/DATA/FORWARD ACs — off the wet/dry path; all use default `MixOptions()` (wet:true) so the engine early-returns the BASE list. Byte-identical to the TUNE-2 grid; green in the full run. |
| AC-15 | TestAC15_RankedPreferFewer (base + 6 twins) | A (re-confirmed) | Comparator and ranking untouched; wet-path unchanged. Passes un-skipped. |
| AC-16 | TestAC16_PaletteOnly | A (re-confirmed) | Membership logic untouched; wet-path returns BASE recipes. |
| AC-17 | TestAC17_InGamut (base + reachable aug) | A (re-confirmed) | `wet:true` → colours identical to BASE; reachable target still ≈0.048 ΔE00 ≤ 5, `outOfGamut isFalse`. |
| AC-18 | TestAC18_OutOfGamut | A (re-confirmed) | Out-of-gamut gate unchanged; unreachable target still > 5 ΔE00, flag true — the paired G3 control for AC-17. |
| AC-19 | TestAC19_CrossMedium (primary + control) | A (re-confirmed) | `byMedium` partition untouched; wet-path returns BASE recipes; oil-target control still selects the oil group. |
| AC-20 | TestAC20_Performance (base + maxPaints=8 aug) | A (re-confirmed) | Timing/count only; wet-path adds nothing to the solve. Capped vs uncapped discrimination intact. |
| AC-22 | TestAC22_ChromaPenalty (base + constructed tie) | A (re-confirmed) | Chroma-penalty ranking on the wet path, untouched by TUNE-4. Penalty-ON ranks 3-paint muted ahead of 2-paint vivid on the guaranteed tie. |

Result: 18 A.

## Behaviour re-grade — PROD-2 (un-pended AC-24; re-confirmed AC-1..AC-6, AC-8, AC-10, AC-13..AC-20, AC-22, AC-23) · graded 2026-10-19

**19 A, 0 B, 0 downgrades, 0 fixes.** Fresh independent adversarial grader (G1–G6), given the prior TUNE-4 grid and asked to justify any downgrade against a named rule. PROD-2 un-pends **AC-24** (provenance tiering). Its lib diff vs BASE `001ab07` is two files: the NEW `lib/src/engine/provenance.dart` (`recipeProvenance(Iterable<Pigment>)` returns the WEAKEST input tier by the source-honesty order `estimated(0) < calculated(1) < measured(2) < confirmed(3)` via private `_sourceStrength`; an empty set → `estimated`), and `lib/src/engine/inverse.dart`, where the old private `_recipeProvenance(subset)` — which returned `any estimated ? estimated : calculated` — is DELETED and its single call site in `_bestRecipeForSubset` now calls `recipeProvenance(subset)` (the `types/provenance.dart` import swapped for `engine/provenance.dart`). No other engine logic changed; parts/ΔE00/gamut/verdict are untouched.

**No carried AC regressed.** The diff changes only how a *recipe's* provenance is derived, and across the entire acceptance suite the only test that reads a recipe's `provenance` is AC-24 itself — verified by `grep -n "\.provenance" test/acceptance/` (the two other hits, `ac01_09_test.dart:279` and `ac10_18_test.dart:120/139`, read a *pigment's* `.provenance`, which the diff does not touch, and the third, `ac19_27_test.dart:566`, is `_retag` preserving `base.provenance`). Moreover the derivation is observationally identical to BASE on every carried path: `synthPigments()` loads `assets/pigments/synthetic_acrylic.json`, whose three paints are all `provenance: estimated` (oil likewise) — so the OLD rule (`any estimated → estimated`, else `calculated`) and the NEW rule (weakest tier; estimated is weakest, strength 0) both return `estimated` for any synthetic-palette recipe. Nothing a carried test observes moves. Confirmed empirically: full `dart test` → **192 pass / 8 skip**; `dart test test/acceptance -x stretch` → **28 pass / 6 skip** (AC-24 runs un-skipped, green); the new `test/provenance_test.dart` → **6 pass** pinning every tier branch (empty→estimated, all-calculated→Calculated, all-measured→Measured, measured+calculated→Calculated both orders, +estimated→Estimated, confirmed strongest).

**AC-24 discrimination — genuine and decisive, grade A.** The test exercises the tiering logic through the public surface (`Recipe.provenance`) with two configured Givens, each the lever that answers (G2). First it re-tags the synthetic dataset palette to `calculated` via `_retag` and solves — asserting the recipe is `Provenance.calculated` ("not Measured and not Estimated"). Then it re-tags a single paint to `measured` (the user's own tube), proves the solve actually used it (`parts.keys contains tube.id`, so the reading is non-vacuous — G1), and asserts the recipe is `Provenance.measured`. The `_retag` exercise is valid and honest: `recipeProvenance` reads *only* `pigment.provenance` (the K,S data is irrelevant to the tier), so re-tagging is exactly the right and only lever for the Given — it configures the input tiers and the output tier must follow. The two assertions together reject every named wrong impl and discriminate decisively (G5): a model that **claims Measured from the dataset** fails assertion 1 (calculated palette → must be Calculated); a model that returns **Estimated from measured data** fails both (asserts == calculated / == measured, never estimated); a model that **ignores paint sources** / returns a constant cannot satisfy both tiers at once. I confirmed this empirically by adversarial mutation: forcing `recipeProvenance` to always-`calculated` (the OLD behaviour) → AC-24 FAILS on the measured-tube assertion; forcing always-`measured` → AC-24 FAILS on the calculated-palette assertion; the production impl passes both (file restored clean after). Assertions are at the exact-value grain (G4: `== Provenance.calculated` / `== Provenance.measured`, not a looser predicate); one AC only (G6). The estimated-drag-down and confirmed branches are not in this AC's scope (its Then is purely the Calculated-vs-Measured distinction) and are pinned by the unit test — not a G5 *limited* gap.

| AC | Test | Grade | Justification |
|---|---|---|---|
| AC-24 | TestAC24_Provenance | **A** (un-pended this phase) | Reads `Recipe.provenance` for a calculated-dataset palette and a single user-measured tube. **G1:** both solves `isNotEmpty`; measured-tube solve asserted to use the tube (`parts.keys contains tube.id`) before its Then. **G2:** tier produced by the real engine reading each paint's real `provenance` via `recipeProvenance`; `_retag` is the only valid lever (derivation reads provenance alone). **G3:** positive exact-equality Thens; synchronous, no settle needed. **G4:** `== Provenance.calculated` / `== Provenance.measured` at tier grain. **G5:** rejects claims-Measured-from-dataset (assertion 1), Estimated-from-measured (both), source-ignoring/constant (both) — confirmed by mutation (always-calculated and always-measured each fail). **G6:** one AC. |
| AC-1..AC-6, AC-8, AC-10, AC-13, AC-14 | (as prior bands) | A (re-confirmed) | COLOR/KM/DATA/FORWARD ACs — none reads a recipe's provenance; synthetic paints are all `estimated` so OLD and NEW derivations coincide. Byte-identical to the TUNE-4 grid; green in the full run. |
| AC-15 | TestAC15_RankedPreferFewer (base + 6 twins) | A (re-confirmed) | Comparator/ranking untouched; provenance not read. Passes un-skipped. |
| AC-16 | TestAC16_PaletteOnly | A (re-confirmed) | Membership logic untouched; provenance not read. |
| AC-17 | TestAC17_InGamut (base + reachable aug) | A (re-confirmed) | Gamut/ΔE00 unchanged; reachable target still within ΔE00 ≤ 5, `outOfGamut isFalse`. |
| AC-18 | TestAC18_OutOfGamut | A (re-confirmed) | Out-of-gamut gate unchanged; the paired G3 control for AC-17. |
| AC-19 | TestAC19_CrossMedium (primary + control) | A (re-confirmed) | `byMedium` partition untouched; both media's paints are `estimated`, so recipe provenance unchanged; oil-target control still selects the oil group. |
| AC-20 | TestAC20_Performance (base + maxPaints=8 aug) | A (re-confirmed) | Timing/count only; provenance derivation adds negligible O(subset) work. Capped-vs-uncapped discrimination intact. |
| AC-22 | TestAC22_ChromaPenalty (base + constructed tie) | A (re-confirmed) | Chroma-penalty ranking untouched; provenance not read. Penalty-ON ranks 3-paint muted ahead of 2-paint vivid on the guaranteed tie. |
| AC-23 | TestAC23_WetDry | A (re-confirmed) | Wet/dry state transform untouched; the dry branch and provenance derivation are independent. Parts/provenance preserved across the toggle; passes un-skipped. |

Result: 19 A.

## Behaviour re-grade — PROD-3 (un-pended AC-25; re-confirmed AC-1..AC-6, AC-8, AC-10, AC-13..AC-20, AC-22, AC-23, AC-24) · graded 2026-10-19

**20 A, 0 B, 0 downgrades, 0 fixes.** Fresh independent adversarial grader (G1–G6), given the prior PROD-2 grid and asked to justify any downgrade against a named rule. PROD-3 un-pends **AC-25** (interchangeable measured-pigment vs single-constant baseline engines behind one `MixingEngine` interface, with an A/B report). Its lib diff vs BASE `8eb47a5` is additive and confined to two files plus one untracked file: the previously-stub `lib/src/engine/spectral_baseline_engine.dart` is filled in (`SpectralBaselineEngine implements MixingEngine` — reduces each paint to its per-wavelength `K/S` ratio and mixes those ratios linearly, the classic single-constant KM law, then the identical `kmReflectance` → `saundersonToMeasured` → `spectrumToColour` pipeline as the two-constant engine, with the same medium-partitioned subset solver, ΔE00-then-fewer-paints ranking, and out-of-gamut gate); a NEW `lib/src/ab/ab_harness.dart` (`ABHarness`/`ABReport` — drives N engines through the same `inverse(target, palette, opts)` on a shared swatch set and reports each engine's best-recipe ΔE00 per swatch, `double.infinity` for an empty result); and `lib/pigment_km.dart` adds the single `export 'src/ab/ab_harness.dart';` line. The baseline engine only *reads* existing modules (`deltaE2000Xyz` from `inverse.dart`, `normalizeParts` from `forward.dart`, `kmReflectance`, `saundersonToMeasured`, `recipeProvenance`) — it modifies none of them.

**No carried AC regressed.** The diff adds new types and one export; it does NOT touch `CustomKmEngine`, the solver (`inverse.dart`), `forward.dart`, `provenance.dart`, `saunderson.dart`, or any `types/*`, so the measured engine every other AC test drives (`customEngine()` → `const CustomKmEngine()`) is byte-identical to BASE and nothing any carried test observes can move. The only new public symbols (`SpectralBaselineEngine`, `ABHarness`, `ABReport`, `baselineEngine()`) are referenced by exactly one acceptance test — confirmed by `grep -rn "baselineEngine\|SpectralBaseline" test/acceptance`: only `ac19_27_test.dart:467` (AC-25) and `smoke_test.dart:22` (a type-only `isA<MixingEngine>` smoke check, not an AC). Confirmed empirically: `dart test test/acceptance -x stretch` → **29 pass / 5 skip** (the 5 skips are the genuinely-pending AC-11/DATA-7, AC-12/FORWARD-3, AC-21/TUNE-3 and the two @stretch S6 ACs; AC-25 now runs un-skipped and green — up from PROD-2's 28 pass / 6 skip, the one moved test).

**AC-25 discrimination — genuine and decisive, grade A.** AC-25 requires interchangeability (both engines behind the one `MixingEngine` surface, driven by the identical `inverse(target, palette, opts)` call with no caller change) plus A/B reporting (each engine's ΔE00 on the same swatch set), and its stated Rejects is "a baseline wired outside the interface / wired differently." The test asserts both builders return `isA<MixingEngine>()` (G1, before the When), drives both through one closure typed `MixingEngine engine` calling the real `inverse(...).first.deltaE00` on a shared 3-swatch set (G2 — the real engines answer; the inline helper is the production `ABHarness._bestDelta` logic, not a fake overriding the engine), then asserts `hasLength(swatches.length)` on each row and `isNonNegative` + `isFinite` on each of the six distances (G4, at the per-swatch grain the "each engine reports a finite ΔE00 per swatch" step names). I confirmed the rejects bite by adversarial mutation of `SpectralBaselineEngine.inverse` (file restored byte-identical afterward, verified by `diff`): a baseline that **throws `UnimplementedError`** (not wired) → AC-25 FAILS; one that **returns empty recipes** → FAILS on `.first`; one that **returns a negative (or NaN) ΔE00** → FAILS on `isNonNegative`/`isFinite`. A non-`MixingEngine` baseline is rejected at compile time (the one-signature closure) and by `isA<MixingEngine>()`; a "wired differently" baseline cannot be driven by the same call. The test deliberately does NOT assert the two engines' distances **differ** — a baseline identical to the measured engine would pass — but that is correct for this AC: the AC text requires interchangeability + reporting, not divergence (divergence is a property the harness *surfaces*, not a guarantee AC-25 makes; the baseline's own solve correctness is out of this AC's scope). So the missing divergence assertion is not a G5 gap against what the AC requires. One AC only (G6); positive synchronous Thens, no settle needed (G3). Minor note (not grade-affecting): the acceptance test inlines the harness's per-swatch best-ΔE00 rather than invoking `ABHarness.run()`; the shipped `ABHarness`/`ABReport` class is separately pinned by its own untracked unit test (`test/ab_harness_test.dart`).

| AC | Test | Grade | Justification |
|---|---|---|---|
| AC-25 | TestAC25_ABEngines | **A** (un-pended this phase) | Drives the measured and single-constant baseline engines through one `MixingEngine` closure on a shared 3-swatch set. **G1:** both builders asserted `isA<MixingEngine>()` before the When. **G2:** the real engines answer via the real `inverse`; the inline A/B helper is the production `ABHarness` logic, not a fake. **G3:** positive synchronous Thens. **G4:** `hasLength(3)` per row; `isNonNegative` + `isFinite` on each of the 6 distances (per-swatch grain). **G5:** rejects a baseline that is not a MixingEngine (compile + `isA`), throws/not-wired, returns empty (`.first`), or returns NaN/negative ΔE00 — all confirmed by mutation. Not asserting divergence is correct (AC requires interchangeability + reporting, not divergence). **G6:** one AC. |
| AC-1..AC-6, AC-8, AC-10, AC-13, AC-14 | (as prior bands) | A (re-confirmed) | COLOR/KM/DATA/FORWARD ACs — none references the baseline engine or the A/B harness; `CustomKmEngine` byte-identical to BASE. Green in the full run. |
| AC-15 | TestAC15_RankedPreferFewer (base + 6 twins) | A (re-confirmed) | Measured-engine comparator/ranking untouched; baseline engine is a disjoint new type. Passes un-skipped. |
| AC-16 | TestAC16_PaletteOnly | A (re-confirmed) | Membership logic untouched; no new symbol reaches it. |
| AC-17 | TestAC17_InGamut (base + reachable aug) | A (re-confirmed) | Gamut/ΔE00 of `CustomKmEngine` unchanged; reachable target still within ΔE00 ≤ 5, `outOfGamut isFalse`. |
| AC-18 | TestAC18_OutOfGamut | A (re-confirmed) | Out-of-gamut gate unchanged; the paired G3 control for AC-17. |
| AC-19 | TestAC19_CrossMedium (primary + control) | A (re-confirmed) | `byMedium` partition in the measured engine untouched; oil-target control still selects the oil group. |
| AC-20 | TestAC20_Performance (base + maxPaints=8 aug) | A (re-confirmed) | Timing/count on `CustomKmEngine` only; the new baseline adds no work to the measured solve. Capped-vs-uncapped discrimination intact. |
| AC-22 | TestAC22_ChromaPenalty (base + constructed tie) | A (re-confirmed) | Chroma-penalty ranking untouched; the baseline (which omits the penalty) is never invoked here. Penalty-ON ranks 3-paint muted ahead of 2-paint vivid on the guaranteed tie. |
| AC-23 | TestAC23_WetDry | A (re-confirmed) | Wet/dry state transform on `CustomKmEngine` untouched; the baseline predicts wet-only and is not driven by this test. |
| AC-24 | TestAC24_Provenance | A (re-confirmed) | `recipeProvenance` untouched (the baseline reuses it read-only); recipe provenance tiering unchanged. Passes un-skipped. |

Result: 20 A.

## Behaviour re-grade — COLOR-4 (10° observer re-base; re-grade every un-pended AC) · graded 2026-10-19

**22 A, 0 B, 0 downgrades, 0 fixes** (22 test rows across the 20 un-pended ACs). Fresh independent adversarial grader (G1–G6), given the prior PROD-3 grid and asked to justify any downgrade against a named rule. COLOR-4 re-bases the colour pipeline from the CIE 1931 2° to the CIE 1964 10° observer (D-14 / G-9). The grader first confirmed the change is **constants/doc-only** — `cmf_d65_weights.dart` (three weight vectors + `yBarD65Sum`=1161.677 recomputed from the 10° CMF×D65; the method validated by reproducing the prior 2° vectors exactly from the same `colour-science` source) and the **Lab reference white** `(0.95047,1.0,1.08883)`→`(0.94811,1.0,1.07304)` moved in lockstep across `inverse.dart`, `wet_dry.dart` and the acceptance yardstick `colour_math.dart`, plus the AC-1 fixture/unit white and doc comments — with no signature or logic change. Every engine colour output shifts ≈0.1–0.5 ΔE00.

**No AC weakened or flipped.** Because the engine colour *and* the independent yardstick white moved together, every relative-ΔE00 / off-colour-path test is structurally insensitive, and every absolute-threshold test keeps ≥0.9 ΔE00 head-room (measured by the grader via a throwaway probe, not estimated): **AC-1** ΔE00 0.084 vs ≤1 (published XYZ is still an independent CIE constant, so a mis-normalized/unweighted backend still fails); **AC-17** best 4.06 vs ≤5 (reachable aug 0.045 vs a ≈6.4 coarse-grid miss — refinement reject intact); **AC-18** 32.45 vs >5; **AC-23** dE(dry,wet) 3.09 vs >0.5, dryY<wetY, hue +3.0°. **AC-13** relative chroma 0.0125 (KM mix) < 0.0372 (RGB blend) — the subtractive-vs-additive inequality cannot flip. **AC-2** is untouched by the re-base (OKLab-space mapper, hardcoded OOG input; the 1e-6 hidden-hard-clip reject holds at red = −1.0e-7).

| AC | Test | Grade | Notes |
|---|---|---|---|
| AC-1 | TestAC01_SpectrumToColour | **A** (re-based) | ΔE00 **0.084** vs ≤1 (margin 0.92); engine + published white re-based in lockstep, residual = documented 400–700 nm truncation; Y=1.0 exact, sRGB white; rejects dropped-illuminant / wrong-normalization. |
| AC-2 | TestAC02_GamutMap | A (re-confirmed) | Untouched by the re-base (OKLab mapper, own matrices, hardcoded OOG fixture); unclamped reported-linear red −1.0e-7 inside ±1e-6 by 10× — hidden-hard-clip reject intact. |
| AC-3 | TestAC03_KmRoundTrip | A (re-confirmed) | Off colour path. Physical [0,1] + reciprocal-root reject + K/S=0→R=1 + round-trip. |
| AC-4 | TestAC04_Saunderson | A (re-confirmed) | Off colour path. Per-bin full formula + anchor + per-medium/no-op controls. |
| AC-5 | TestAC05_TwoConstantMix | A (re-confirmed) | Relative ΔE00 (self-mix & order equality <1e-6, controls >1); all engine outputs move together. |
| AC-6 | TestAC06_Artifact | A (re-confirmed) | Off colour path. Field checks + decode-equality. |
| AC-8 | TestAC08_Resample | A (re-confirmed) | Off colour path. Linear-ramp 1e-5 + nearest-bin reject. |
| AC-10 | TestAC10_MasstoneTint | A (re-confirmed) | Off colour path (independent opaque-KM reference, no colour space/white). |
| AC-13 | TestAC13_Desaturation | A (re-confirmed) | Relative chroma: kmMix 0.0125 < rgbBlend 0.0372 (margin 0.0247, KM ~⅓); both from the same re-based engine → inequality unaffected; pures chromatic, hue diff 124°. |
| AC-14 | TestAC14_Normalize | A (re-confirmed) | Asserts `normalizeParts` directly + scale-invariance <1e-6 + ratio control; relative. |
| AC-15 | TestAC15_RankedPreferFewer (base + 6-twin tie) | A (re-confirmed) | Relative ordering/membership/Σ1; bit-exact tie → non-decreasing paint count; observer-independent. |
| AC-16 | TestAC16_PaletteOnly | A (re-confirmed) | Membership only; no colour threshold. |
| AC-17 | TestAC17_InGamut (base + reachable aug) | A (re-confirmed) | best.deltaE00 **4.06** vs ≤5 (tightest absolute margin, 0.94); reachable off-grid tint 0.045 vs ≈6.4 coarse-grid miss — refinement reject separated; yardstick + solver both re-based. |
| AC-18 | TestAC18_OutOfGamut | A (re-confirmed) | best.deltaE00 **32.45** vs >5 (margin 27.4), flagged, verdict "out of gamut"; G3 pair for AC-17. |
| AC-19 | TestAC19_CrossMedium (+ oil control) | A (re-confirmed) | Single-medium partition + relative oil/acrylic ΔE00 control. |
| AC-20 | TestAC20_Performance (+ maxPaints=8 aug) | A (re-confirmed) | Timing/count only; re-base adds negligible compute; capped-vs-uncapped reject intact. |
| AC-22 | TestAC22_ChromaPenalty (base + constructed tie) | A (re-confirmed) | Constructed tie equalizes the engine's own `deltaE2000Xyz` by bisection → observer-independent; penalty-ON promotes 3-paint muted ahead of 2-paint vivid. |
| AC-23 | TestAC23_WetDry | A (re-confirmed) | dE(dry,wet) **3.09** vs >0.5 (margin 2.59); dryY 0.129 < wetY 0.150 (darker), hue +3.0°>0.5°; parts unchanged (state transform); direction config-pinned; wet_dry white re-based in lockstep. |
| AC-24 | TestAC24_Provenance | A (re-confirmed) | Provenance labels only; off colour path. |
| AC-25 | TestAC25_ABEngines | A (re-confirmed) | Relative: finite non-negative ΔE00 per swatch, both engines behind one `MixingEngine` call. |

Result: 22 A. (Pending AC-7/9/11/12/21/26/27 authored against the 10° basis in their own later phases — not graded here.)

## Behaviour re-grade — DATA-5 (un-pended AC-7; re-confirmed the other 20 un-pended ACs) · graded 2026-10-19

**21 A, 0 B, 0 downgrades, 0 fixes** — all 21 un-pended ACs grade A (AC-1…AC-6, AC-7, AC-8, AC-10, AC-13…AC-20, AC-22…AC-25). Fresh independent adversarial grader (G1–G6), given the prior COLOR-4 grid and asked to justify any downgrade against a named rule. DATA-5 un-pends **AC-7** (`TestAC07_RoundTripFidelity`) by shipping the real Golden/RIT acrylic dataset and switching the fixture it reads from the placeholder to that real data — **the AC-7 test body was NOT rewritten** (the assigned "no test rewrite" augmentation; the only diff to the AC-7 test is the fixture rename `acrylicPublishedPlaceholder`→`acrylicPublished`).

**The change set is additive test-harness + a new fixture; NO `lib/` file changed** (`git diff 8c3db02 --stat` touches only 7 files under `test/`, all verified). New artifacts: `assets/pigments/acrylic.json` (78 Golden/RIT acrylic paints, grid 400–700@10 nm/31 bins, every `s ≡ 1.0`, every `provenance: calculated`, unique ids — all confirmed by a parse), `test/acceptance/harness/acrylic_published_data.dart` (a generated `const Map` of 78 published D65/10° L*a*b* triples — count confirmed), and the offline `tool/ingest/`. `colour_math.dart` only ADDS `labToXyz`/`_linearToSrgb`/`xyzToSrgb`/`colourFromLab` (verified every diff hunk is a new block; no existing function touched). `fixtures.dart` replaces the placeholder `acrylicPublished` with a real one whose `table` is a **separate** artifact decoded via the public `PigmentTable.fromArtifact(PigmentArtifactCodec.decode(File('assets/pigments/acrylic.json').readAsStringSync()))` — the synthetic solver palette (`load(Medium.acrylic)` / `synthPigments()`) is untouched.

**The carried 20 cannot move — verified, not assumed.** `grep -rn acrylicPublished test/` shows the real fixture is referenced only by `smoke_test`, AC-7 (live) and AC-11 (`ac10_18:132`, still pending/DATA-7); `grep -rn colourFromLab\|labToXyz\|xyzToSrgb test/` shows the new harness helpers are referenced only by `fixtures.dart` building `acrylicPublished.published`. No un-pended carried AC references the real fixture or the new helpers, no `lib/` code changed, and `synthPigments`/`oogColour`/the solver palette are byte-identical — so every carried AC runs identical code and its COLOR-4 reasoning holds verbatim.

**AC-7 graded adversarially — genuine and decisive, grade A.** Non-vacuous: the test iterates **all 78 paints** (confirmed) and runs an **executable** `expect(deltaE00(rendered.xyz, published[p.id]!.xyz), lessThanOrEqualTo(0.5))` live in the default suite (no longer skipped — `ac('AC-7')` returns null). I measured the real distribution with a throwaway probe (since deleted): **max ΔE00 = 0.1445 (`acrylic.cobalt_blue`), mean 0.0366, 0/78 over 0.5** — a ~0.355 head-room below the ≤0.5 ceiling, confirming COLOR-4's 10° re-base is what makes the threshold reachable (the memory/GATE record of 66/78 > 0.5 under the 2° pipeline). The design leg checks out: `_koverS(p) = k/s` with `s ≡ 1` is the dataset's measured K/S; `kmReflectance` (physical −√ root) and `kmFunction` are **exact** inverses (verified algebraically: `(1−R)²/(2R) = x` for `R = 1+x−√(x²+2x)`), so `spectrumToColour(kmReflectance(_koverS(p)))` renders `spectrumToColour(measured_R)` with no Saunderson step — correctly matching the spec's "rendered to its *opaque reflectance*" (Band 1's AC-7 note). This makes AC-7 an **observer-fidelity check**: the engine's 10° colour of the dataset's measured reflectance vs the dataset's published D65/10° Lab (converted through the harness `labToXyz`). That is exactly the correct thing for this AC and is what G-9 was about — a G5 rejects-coverage *flag* (the KM leg is near-identity so the broader "wrong k1,k2" reject is out of scope, as Band 1 already recorded), **not a downgrade**.

**Adversarial mutations (each restored byte-identical; verified).** (1) Perturbed the published map (`alizarin_crimson_hue` L 27.9999→47.9999) → AC-7 **FAILS** (rejects a wrong yardstick); restored, `diff` clean. (2) Scaled a paint's K spectrum ×2 in `acrylic.json` → AC-7 **FAILS** (rejects wrong engine data / wrong K); restored, `diff` clean. *(A single 400 nm edge-bin K perturbation did NOT fail — correctly within tolerance, as the 400 nm luminance weight is near-zero; a whole-spectrum scale is the honest discriminating mutation.)* (3) Perturbed the engine observer normalization `yBarD65Sum` 1161.677→1120.0 → AC-7 **FAILS** (rejects a mis-normalized / wrong-observer backend); restored via `git checkout`, `git diff lib/` empty. **Public-surface compliance PASS:** AC-7 imports only the package barrel + harness; the fixture builds Givens via the public `PigmentArtifactCodec.decode` / `PigmentTable.fromArtifact` / `Pigment` fields (`p.k`/`p.s`); the ΔE00 yardstick is the harness's own independent CIEDE2000 (`colour_math.dart`).

**Suite counts (run by the grader).** Full default `dart test` → **208 pass / 6 skip**, all green. Default `dart test test/acceptance` → **+30 ~6** (6 skips = the 6 still-pending AC-9/11/12/21/26/27; AC-7 runs un-skipped and green). `PIGMENT_KM_RUN_PENDING=true dart test test/acceptance` → **+30 −6**: AC-7 passes; the 6 still-pending ACs fail **for cause** — AC-9 on its precondition (G-4/DATA-6), AC-11 on finalized attribution/provenance wording (DATA-7), AC-12 on real measured mixtures (FORWARD-3), AC-21 on the curated palette/ceiling (TUNE-3), AC-26/AC-27 on the @stretch scope gate (G-7).

| AC | Test | Grade | Justification |
|---|---|---|---|
| AC-7 | TestAC07_RoundTripFidelity | **A** (un-pended this phase) | Iterates all 78 real acrylic paints; live `deltaE00(rendered, published) ≤ 0.5` in the default suite. **G1:** `isReal`/`published != null` Givens asserted before the loop (now true since the real data landed). **G2:** the tier/colour comes from the shipped artifact + the real `spectrumToColour`∘`kmReflectance` pipeline — no fake. **G4:** per-paint at the ΔE00 grain, exact ≤0.5 (measured max 0.1445, mean 0.0366, head-room 0.355). **G5:** rejects a wrong yardstick (published-map mutation → FAIL), wrong engine data/K (K×2 mutation → FAIL) and a wrong-observer/mis-normalized backend (`yBarD65Sum` mutation → FAIL); the KM leg being an exact inverse makes it the intended observer-fidelity check (G-9), a flag not a downgrade. **G6:** asserts only the round-trip fidelity. **G3:** positive synchronous Then. Public surface only. |
| AC-1…AC-6, AC-8, AC-10, AC-13, AC-14, AC-16, AC-19, AC-24 | (as COLOR-4 band) | A (re-confirmed) | DATA-5 changed no `lib/` code and no code these tests reach; the new real fixture + harness helpers are referenced only by AC-7 (live) and AC-11 (pending) — verified by grep. Byte-identical code to COLOR-4; all green in the full run. |
| AC-15 | TestAC15_RankedPreferFewer (base + 6-twin tie) | A (re-confirmed) | Comparator/ranking + fixture-independent twins untouched; relative ordering/membership/Σ1 hold. |
| AC-17 | TestAC17_InGamut (base + reachable aug) | A (re-confirmed) | Solver/gamut path untouched; reachable target still ≤5, refinement reject intact. |
| AC-18 | TestAC18_OutOfGamut | A (re-confirmed) | Gamut gate untouched; unreachable green still >5, flagged — G3 pair for AC-17. |
| AC-20 | TestAC20_Performance (base + maxPaints=8 aug) | A (re-confirmed) | Timing/count only; capped-vs-uncapped reject intact. |
| AC-22 | TestAC22_ChromaPenalty (base + constructed tie) | A (re-confirmed) | Chroma-penalty ranking untouched; penalty-ON promotes 3-paint muted ahead of 2-paint vivid on the guaranteed tie. |
| AC-23 | TestAC23_WetDry | A (re-confirmed) | Wet/dry state transform untouched; parts preserved, dry darker, hue-shifted. |
| AC-25 | TestAC25_ABEngines | A (re-confirmed) | Both engines behind one `MixingEngine` call; finite non-negative ΔE00 per swatch. |

Result: 21 A, 0 B, 0 downgrades. (Still-pending AC-9/11/12/21/26/27 fail for cause in the red baseline and are graded in their own later phases — not here.)

## Behaviour grade — STRETCH-2 (un-pended AC-26) · graded 2026-10-19

**AC-26 = A (1 new test graded; the 21 prior un-pended ACs are byte-identical and
not re-graded — STRETCH-2 adds a new module `lib/src/stretch/glazing.dart` that
nothing else imports, and touches only the AC-26 test + the pending-gate mirror
maps + the barrel export).** Fresh independent adversarial grader, G1–G6, with
required library mutations (each restored, re-verified green).

`TestAC26_Glazing` (@stretch) drives `glazedReflectance` through the public barrel.

| G | Finding |
|---|---|
| G1 | X finite & >0 and Rg a valid grid-length (0,1] spectrum asserted through the public surface before the `glazedReflectance` When. |
| G2 | Behaviour comes from the real `glazedReflectance`/`mixTwoConstant`/`kmReflectance` (barrel) — confirmed by mutation (lib edits move the result). |
| G3 | Limit Thens settled with paired controls that move: thin X→ground vs thick X→opaque; `sawDepartureFromOpaque` proves the finite reading differs from the opaque form. |
| G4 | Per-wavelength over the 31-bin grid at exact tolerances (thick≈opaque 1e-5, thin≈ground 1e-3, self-consistency 1e-5); the spec's "X→∞ ≈ opaque form" control present. |
| G5 | Named Reject proven: mutation 1 (return the opaque form, ignoring X/ground) → FAIL; denominator sign flip → FAIL; remove the coth saturation clamp (overflow→NaN) → FAIL on the X→∞ control. |
| G6 | AC-26 only (AC-27 is a separate test). |

Mutations (each restored byte-identical; AC-26 re-green after each): (1) `out[i]=a−b`
opaque reuse → FAIL; (2) `a − rg`→`a + rg` → FAIL; (3) drop `y ≥ cothSaturation`
clamp → FAIL (control). No correctness bug found; implementation matches design §3.4
and the X→∞ ⇒ R∞ = a−b = kmReflectance(K/S) reduction was verified algebraically.

## Behaviour grade — STRETCH-3 (un-pended AC-27) · graded 2026-10-19

**AC-27 = A (fixed in-phase, fix pass 1/3; 1 new test graded; the 22 prior un-pended
ACs — AC-1…AC-8, AC-10, AC-13…AC-20, AC-22…AC-26 — are byte-identical and not
re-graded: STRETCH-3 adds a new module `lib/src/stretch/metamerism.dart` that
nothing else imports, and touches only the AC-27 test + the pending-gate mirror
maps + the barrel export).** Fresh independent adversarial grader, G1–G6, with
required library mutations (each restored, re-verified green).

`TestAC27_Metamerism` (@stretch) drives `assessMetamerism` through the public barrel.

| G | Finding |
|---|---|
| G1 | Two distinct illuminants and a valid, spectrally-different second recipe asserted through the public surface before the When; "equal under D65" is read from the public `deltaE00Reference` output after the When (necessarily — it is a distinct field from the index/flag under test) and before the Thens. |
| G2 | Illuminants are real Planckian SPD fixtures; the metameric black is built only via the public `spectrumToColour`; index + flag come from the real `assessMetamerism`, no test-side override. |
| G3 | Fragile flag shown to change (robust `isFalse` vs fragile `isTrue`); the negative "not fragile" reading is paired with a control (the illuminant-stable poor match) whose test-light error is large yet flag is off — the reading can move both ways. |
| G4 | Relative ordering `fragile.index > robust.index` matches "higher index"; exact grains `dRef < 1e-3`, equal-within-`1e-3`, `singleIlluminant.index < 1e-6`, both flags asserted with reasons. |
| G5 | **B→A, fixed in-phase.** Initial grade B: with both primary recipes at ΔE_ref≈0, a wrong `index = ΔE_test` (the AC's own "one illuminant only" reject, test-light direction) sneaked past — the single-illuminant control (`test==reference ⇒ 0`) caught only a *reference*-only index. Fix: added a poor-but-illuminant-STABLE control (same shape ×0.7: ΔE_ref≈7.9, degradation≈0) asserting *not fragile* despite a large test-light error. Now rejects `index = ΔE_test`. |
| G6 | AC-27 only (AC-26 is a separate test; the stable control still asserts only AC-27's index/flag). |

Mutations (each restored byte-identical; AC-27 re-green after each): (a) `index =
max(0, dRef)` reference-only → FAIL; (b) `_labUnder` ignores illum (`m = 1.0`) →
FAIL; (c) invert flag `index <= threshold` → FAIL; (d) drop von-Kries white norm
(constant divisor) → FAIL; (e) `index = max(0, dTest)` test-only → **FAIL after the
fix** (PASS before it — the finding). No correctness bug found; `index = max(0,
ΔE_test − ΔE_ref)` is the correct degradation measure and the observer-reweight +
per-illuminant von-Kries adaptation are sound.
