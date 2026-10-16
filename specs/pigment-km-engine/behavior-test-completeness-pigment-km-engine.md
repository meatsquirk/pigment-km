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
