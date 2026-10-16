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
- **AC-19 (SOLVER-5):** add a constructed cross-medium-tempting target as a control.
- **AC-21 (TUNE-3):** confirm/tune the real naturalistic chroma ceiling (harden), don't merely swap in the shipped palette.
- **AC-22 (TUNE-2):** construct the guaranteed equal-ΔE00 2-vs-3-paint tie the test depends on, together with the un-pend (until then the test is over-constrained on `sawTie`).
- **AC-23 (TUNE-4 / G-2):** resolve the forward-vs-inverse wet/dry interface so the best recipe is stable across wet/dry states.
