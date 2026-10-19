# Module STRETCH — glazing + metamerism (optional S6)

**Status:** In progress — **STRETCH-2 ✅ Done 2026-10-19 (AC-26 glazing, A)**; STRETCH-3 (AC-27 metamerism) startable (own session, G-7 ✅).
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/stretch/glazing.dart` (finite-thickness layering), `lib/src/stretch/metamerism.dart` (multi-illuminant index)
**Depends on:** FORWARD, COLOR · **Blocks:** SIGNOFF-1 (G-7 enabled STRETCH → now a real dependency)

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 2 (STRETCH-2) | behavior | AC-26 | ✅ Done | 6.86M | 13m 23s |
| 3 (STRETCH-3) | behavior | AC-27 | ⬜ Todo — startable (G-7 ✅) | | |

## Interface reconciliation

Design §3.4 (finite-thickness layering — the opaque dataset doesn't give transparent-glaze params, so this uses assumed film thickness, a known caveat) and §9 (metamerism across D65 + a warm studio illuminant). `@stretch`-tagged scenarios are excluded from the default acceptance run until G-7. "Only if value is proven" (design §8).

## Open gates
- **G-7** (decision) ✅ Resolved 2026-10-19: **Build STRETCH** — glazing + metamerism in scope (Matt Quirk). Both phases unblocked.
- **G-2** blocks all behavior. ✅ Resolved 2026-10-16 (acceptance tests approved).

## Phase 2 — STRETCH-2: finite-thickness glazing (AC-26)

- **Kind:** behavior · **Target AC:** AC-26 (full) · **Depends on:** FORWARD-4 (G-7) · **Blocks:** —
- **Files:** `glazing.dart`
- **Tasks:** implement the §3.4 layering equation (glaze over ground Rg at thickness X); verify R→opaque as X→∞ (control).
- **Exit criteria:** analyze clean; 100% touched; layering eqn correct; large-X ≈ opaque form.
- **Acceptance gate:** un-pend AC-26; `TestAC26_Glazing` (@stretch) green.

### Result · Checkpoint

**Result (STRETCH-2 ✅ Done 2026-10-19).** Finite-thickness KM glazing shipped as a new module; AC-26 un-pended and green (A).

- **Landed:** `lib/src/stretch/glazing.dart` — `glazedReflectance({KmMix glaze, double thickness, Spectrum ground})`, the design §3.4 single-layer KM layering equation `R = (1 − Rg·(a − b·coth(b·S·X))) / (a − Rg + b·coth(b·S·X))` with `a = 1 + K/S`, `b = √((K/S)²+2K/S)`, per-wavelength over the canonical grid. Built on the two-constant `KmMix` (Kmix/Smix) so `S·X` is the optical thickness. Two guarded limits: `b < 1e-9` (K/S→0) takes `b·coth → 1/(S·X)`; optical thickness `≥ 30` returns the exact opaque form (`coth → 1`) and avoids `exp` overflow. Exported from the barrel.
- **Reduces to the opaque form** `kmReflectance(K/S) = a − b` as X→∞ (verified algebraically: (a−b)(a+b)=1 ⇒ R→a−b independent of Rg); `R→Rg` as X→0.
- **Tests:** new unit suite `test/stretch_glazing_test.dart` (12 tests: hand-computed closed-form general case 0.538298; opaque/vanishing/self-consistency limits; K=0 branch 0.75; the 6 validation branches). AC-26 acceptance test un-pended in `ac19_27_test.dart` and driven through the public API only — Givens (X finite>0, Rg valid (0,1] spectrum) checked; controls for X→∞≈opaque, X→0≈ground, finite lies strictly between ground and opaque (rejects opaque-form reuse), and self-consistency over an own-colour ground. Pending-gate mirror maps updated (`pending.dart` row deleted; `pending_gate_test.dart` `unpendedACs['AC-26']='STRETCH-2'`).
- **Verification:** `dart analyze` clean (5 touched files). Full `dart test` → **221 pass / 5 skip / 0 fail** (skips = still-pending AC-9/11/12/21 + @stretch AC-27). Coverage gate vs BASE `eb7618e` → **PASS** (`glazing.dart` 21/21; `pigment_km.dart` no executable lines). Acceptance default → **31 pass / 5 skip**, AC-26 green. Red baseline `PIGMENT_KM_RUN_PENDING=true dart test test/acceptance -x stretch` → the 4 remaining pending ACs red for cause (AC-9/11/12/21), each naming its owner.
- **Acceptance gate (AC-26):** `TestAC26_Glazing` (@stretch) green.
- **Grade:** fresh independent adversarial grader → **A** (G1–G6 all pass). Mutations: opaque-form reuse → FAIL (the named Rejects); denominator sign flip → FAIL; remove the coth saturation clamp (overflow→NaN) → FAIL on the X→∞ control. No correctness bug found.
- **Augmentation:** AC-26's STRETCH-2 augmentation (freeze the layering API, replace the G-7 scope-gate placeholder with the full Given/When/Then incl. the X→∞ control) — **made** (⬜ Open (G-7) → ✅).
- **Fix passes:** 0/3 (green on the first full run).
- **Tokens / Time:** 6.86M / 13m 23s.

### Checkpoint / Handoff

- **Frozen API (STRETCH-2):** `glazedReflectance({required KmMix glaze, required double thickness, required Spectrum ground}) → Spectrum`, exported from `package:pigment_km/pigment_km.dart`. Throws `ArgumentError` on non-finite/≤0 thickness or off-grid spectra. `thickness` is in the reciprocal unit of `S`; `S·X` is the dimensionless optical thickness.
- **Verification commands (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"` first. Analyze `dart analyze`; unit `dart test`; coverage `bash tool/coverage_gate.sh <BASE>`; AC-26 `dart test test/acceptance/ac19_27_test.dart -t stretch`; red baseline `PIGMENT_KM_RUN_PENDING=true dart test test/acceptance -x stretch`.
- **Known caveat (design §3.4):** the opaque datasets give no transparent-glaze params, so a real use supplies an assumed film thickness `X` and ground `Rg` — glazing is a predictive layer over the two-constant mix, not fit to measured glaze data.
- **Next (STRETCH-3, AC-27 metamerism):** build `lib/src/stretch/metamerism.dart` (own session). The `illuminants` fixture (d65 + warm, still a Planckian placeholder) is staged; `_stretchScopeApproved` const in `ac19_27_test.dart` is still referenced only by the AC-27 placeholder — STRETCH-3 removes it. After STRETCH-3, SIGNOFF-1 is the only remaining phase.

## Phase 3 — STRETCH-3: metamerism index (AC-27)

- **Kind:** behavior · **Target AC:** AC-27 (full) · **Depends on:** COLOR-2, FORWARD-2 (G-7) · **Blocks:** SIGNOFF-1
- **Files:** `metamerism.dart`
- **Tasks:** evaluate recipes under D65 + a warm studio illuminant; assign a metamerism index; warn on illuminant-fragile matches (design §9).
- **Exit criteria:** analyze clean; 100% touched; the degrading recipe gets the higher index; warning fires.
- **Acceptance gate:** un-pend AC-27; `TestAC27_Metamerism` (@stretch) green.

### Result · Checkpoint  <!-- filled on completion -->
