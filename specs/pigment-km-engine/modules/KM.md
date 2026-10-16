# Module KM — Kubelka–Munk physics

**Status:** ✅ Done — KM-2/3/4 complete (reflectance + f(R), Saunderson, two-constant mixing). AC-5's un-pend lands downstream in FORWARD-2 (G-2 routing).
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/km/reflectance.dart` (KM reflectance + inverse f(R)), `lib/src/km/saunderson.dart`, `lib/src/km/mixing.dart` (two-constant Σv·K, Σv·S + concentration)
**Depends on:** CORE · **Blocks:** FORWARD, DATA (ingest round-trip)

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 2 (KM-2) | behavior | AC-3 | ✅ Done | 5.87M | 9m 58s (24m) |
| 3 (KM-3) | behavior | AC-4 | ✅ Done | 7.45M | 15m 00s (15m 07s) |
| 4 (KM-4) | enabler | — (mixing for AC-5) | ✅ Done | 3.94M | 7m 52s (8m 09s) |

## Interface reconciliation

Implements design §3.1 (reflectance + inverse), §3.2 (Saunderson, per-medium k1,k2), §3.3 (two-constant mixing) and §5 (concentration = volume fraction). Opaque/infinite-thickness form (D-5). k1,k2 are per-`MediumConfig`; their authoritative values come from each dataset README (G-5) — until then tests use documented defaults (acrylic ~0.04/~0.6) and assert *structure*, not the literals.

## Open gates

- **G-2** blocks all behavior. **G-5** fixes the authoritative k1,k2 used by DATA's round-trip (not by these property tests).

## Phase 2 — KM-2: reflectance ↔ K/S round-trip (AC-3)

- **Kind:** behavior · **Target AC:** AC-3 (full)
- **Depends on:** CORE-2 · **Blocks:** KM-3
- **Files:** `reflectance.dart`
- **Tasks:** `kmReflectance(KoverS)` = `1 + x − sqrt(x²+2x)`; `kmFunction(R)` = `(1−R)²/(2R)`; elementwise over the grid.
- **Exit criteria:** analyze clean; 100% touched; round-trip within 1e-6 across a sweep of K/S.
- **Acceptance gate:** un-pend AC-3; `TestAC03_KmRoundTrip` green.

### Result

Implemented `kmReflectance` (opaque `R∞ = 1 + x − √(x²+2x)`, the physical −√ root)
and `kmFunction` (`K/S = (1−R)²/(2R)`), both elementwise over the input spectrum
(one output sample per input sample), in `lib/src/km/reflectance.dart`.

- **Gates (all green, first full run — fix passes 0/3):** `dart analyze` clean;
  `dart test` 87 pass / 25 skip / 0 fail; coverage PASS (`reflectance.dart`
  11/11 lines — line-only metric); acceptance default green (9 pass / 25 pending);
  `TestAC03_KmRoundTrip` green under `PIGMENT_KM_RUN_PENDING=true`.
- **Grade gate:** fresh independent adversarial subagent, every un-pended AC test
  (AC-1, AC-3) → **2 A** (no downgrade from Band 1 grid). AC-3's range check in
  `[0,1]` rejects the wrong +√ root (the round-trip alone can't — the two roots
  are reciprocals and f(R)=f(1/R)); 1e-5 round-trip rejects a dropped constant.
- **Un-pend:** deleted AC-3 from `pendingACs` (`pending.dart`), added `AC-3: KM-2`
  to `unpendedACs` (`pending_gate_test.dart`), removed the two KM-2 stub rows from
  `backends_stub_test.dart`.
- **Unit tests:** new `test/km_test.dart` — independent closed-form reference,
  physical range, K/S=0→R=1, x=1→2−√3, strict monotonicity, f(R) known point,
  round-trip across a K/S sweep (0…100) with value-scaled tolerance (Float32
  amplifies round-trip error ~1/(2R²) for strong absorbers).
- **No augmentations** assigned to or newly enabled by this phase.
- Tokens: 5.87M · Time: 9m 58s active (24m 14s wall) — see ledger.

### Checkpoint / Handoff

- **Frozen interface:** `kmReflectance(Spectrum) → Spectrum` and
  `kmFunction(Spectrum) → Spectrum` are exact inverses within fp tolerance over
  `(0,1]` reflectance / `≥0` K/S; elementwise, output length == input length.
  Both exported via the package barrel. KM-3 (`saunderson.dart`) composes with
  these; FORWARD renders `spectrumToColour(kmReflectance(·))` (see AC-7/AC-13).
- **Verification commands (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"`
  first. Analyze `dart analyze`; unit `dart test`; coverage
  `bash tool/coverage_gate.sh <BASE>` (line-only); acceptance default
  `dart test test/acceptance`; run-pending `PIGMENT_KM_RUN_PENDING=true dart test
  test/acceptance`. Un-pend = delete the AC row in `pending.dart` **and** add it
  to `unpendedACs` in `pending_gate_test.dart` **and** drop the stub's
  `throwsUnimplementedError` row(s) in `backends_stub_test.dart`.
- **Next phase KM-3 (AC-4 Saunderson, `saunderson.dart`):** implement
  internal→measured and its inverse taking `(k1,k2)` from `MediumConfig`; prove
  acrylic and oil configs carry distinct constants. `configForMedium`,
  `saundersonToMeasured`, `saundersonToInternal` are still Option-A stubs (their
  KM-3 rows remain in `backends_stub_test.dart`). Authoritative k1,k2 are gated on
  G-5; until then use documented defaults (acrylic ~0.04/~0.6) and assert
  *structure*, not the literals.
- **Known gaps:** none for AC-3.

## Phase 3 — KM-3: Saunderson correction (AC-4)

- **Kind:** behavior · **Target AC:** AC-4 (full)
- **Depends on:** KM-2 · **Blocks:** KM-4, DATA-5
- **Files:** `saunderson.dart`
- **Tasks:** internal→measured and its inverse (design §3.2) taking `(k1,k2)` from `MediumConfig`; prove acrylic and oil configs carry distinct constants.
- **Exit criteria:** analyze clean; 100% touched; round-trip within 1e-6; two media → two results.
- **Acceptance gate:** un-pend AC-4; `TestAC04_Saunderson` green.

### Result

Implemented the Saunderson surface correction in `lib/src/km/saunderson.dart`:
`configForMedium(Medium)` (a `switch` returning the per-medium `MediumConfig`),
`saundersonToMeasured` (`R_m = k1 + (1−k1)(1−k2)·R_i/(1−k2·R_i)`, elementwise) and
its exact algebraic inverse `saundersonToInternal`. Per-medium constants use the
documented defaults — acrylic k1=0.04/k2=0.6, oil k1=0.05/k2=0.6 (oil's higher
refractive index → larger surface k1); authoritative values remain gated on G-5,
so the tests assert structure, not the literals beyond the documented pin.

- **Gates (all green):** `dart analyze` clean; `dart test` 97 pass / 24 skip / 0
  fail; coverage PASS (`saunderson.dart` 19/19 lines — line-only metric);
  acceptance default green (AC-4 un-pended & green; 24 ACs still pending);
  `TestAC04_Saunderson` green.
- **Grade gate:** fresh independent adversarial subagent re-graded every un-pended
  AC test. First pass: **AC-4 = B** — `TestAC04_Saunderson`'s round-trip is
  mutually-inverse by construction and its two controls differ only in k1, so a
  k2-dropping forward passed (the k2 term unverified; no other suite check covers
  Saunderson). **Fixed in-phase (fix pass 1/3):** added an independent full-formula
  forward reference asserted per bin for both media + a hand-computed anchor
  (R_i=0.2→R_m=0.12727273) + a documented-constant pin. A second fresh grader
  re-graded **AC-4 = A**. Final: **3 A** (AC-1, AC-3 re-confirmed; AC-4 B→A).
- **Un-pend:** deleted AC-4 from `pendingACs` (`pending.dart`), added `AC-4: KM-3`
  to `unpendedACs` (`pending_gate_test.dart`), removed the three Saunderson stub
  rows (+ now-unused `config`) from `backends_stub_test.dart`.
- **Unit tests:** new `test/saunderson_test.dart` — per-medium config defaults,
  hand-computed forward anchors (acrylic & oil at R_i=0.5), not-a-no-op control,
  per-medium distinctness control, round-trip to 1e-6 over both media.
- **Augmentations:** none assigned; the AC-4 hardening strengthens AC-4's own test
  only (its B→A fix), not a neighbour.
- Tokens: 7.45M · Time: 15m 00s active (15m 07s wall) — see ledger.

### Checkpoint / Handoff

- **Frozen interface:** `configForMedium(Medium) → MediumConfig`,
  `saundersonToMeasured(Spectrum, MediumConfig) → Spectrum` and
  `saundersonToInternal(Spectrum, MediumConfig) → Spectrum` are exact inverses
  within fp tolerance over the physical reflectance range; elementwise, output
  length == input length. All exported via the barrel. The forward model is the
  **full** Saunderson (k2 internal-reflection term included) — the AC-4 test pins
  it independently, so a later refactor that drops k2 will fail.
- **Verification commands (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"`
  first. Analyze `dart analyze`; unit `dart test`; coverage
  `bash tool/coverage_gate.sh <BASE>` (line-only); acceptance default
  `dart test test/acceptance`; run-pending `PIGMENT_KM_RUN_PENDING=true dart test
  test/acceptance`. Un-pend = delete the AC row in `pending.dart` **and** add it
  to `unpendedACs` in `pending_gate_test.dart` **and** drop the stub's
  `throwsUnimplementedError` row(s) in `backends_stub_test.dart`.
- **Next phase KM-4 (enabler, `mixing.dart`):** two-constant mixing `Kmix=Σv·K`,
  `Smix=Σv·S` elementwise; concentration = volume fraction (§5); self-mix
  idempotence + order-independence at unit level. AC-5's acceptance gate is in
  FORWARD-2 (G-2 routing). KM-4 composes with `kmReflectance`/`saundersonToMeasured`
  for the forward pipeline (FORWARD renders mixing → reflectance → Saunderson →
  spectrum→colour).
- **G-5 coupling (carry-forward):** the AC-4 acceptance test and the
  `saunderson_test.dart` anchors hard-pin the documented defaults (acrylic
  0.04/0.6, oil 0.05/0.6). When G-5 confirms the authoritative per-medium k1,k2,
  update `configForMedium` **and** both tests' pins/anchors in lockstep.
- **Known gaps:** none for AC-4 (behaviour complete; constants provisional pending G-5).

## Phase 4 — KM-4: two-constant mixing + concentration (enabler — AC-5 un-pends in FORWARD-2)

- **Kind:** enabler · **Target AC:** — (the two-constant-mixing mechanism AC-5 needs; its un-pend moved to **FORWARD-2** per G-2 2026-10-16, because AC-5's colour-level Then runs through `CustomKmEngine.forward`)
- **Depends on:** KM-3 · **Blocks:** FORWARD-2
- **Files:** `mixing.dart`
- **Tasks:** `Kmix=Σv·K`, `Smix=Σv·S` elementwise; concentration = volume fraction (§5); self-mix idempotence; order-independence.
- **Exit criteria:** analyze clean; 100% touched; self-mix==pure colour; permutation invariance (unit-level — AC-5's acceptance gate is in FORWARD-2).

### Result

Implemented the two-constant mixing primitive `mixTwoConstant(List<MixComponent>)
→ KmMix` in `lib/src/km/mixing.dart` (design §3.3, §5): elementwise volume-weighted
sums `Kmix = Σ vᵢ·Kᵢ`, `Smix = Σ vᵢ·Sᵢ`. `MixComponent = ({k, s, weight})` and
`KmMix = ({k, s})` records. Sums accumulate in `Float64List` and narrow to the
`Spectrum`'s `Float32` once, so the result is order-independent at the spectrum's
precision. It sums weights **as given** — no normalisation (that is FORWARD-2's
AC-14, deliberately not hidden here). Guards: non-empty components + each spectrum
`CanonicalGrid.checkLength`. Exported from the barrel.

- **Kind: enabler — no AC un-pended here.** AC-5's acceptance gate is FORWARD-2
  (G-2). So `pending.dart`/`pending_gate_test.dart`/`backends_stub_test.dart` are
  untouched: the 27↔27 bijection keeps AC-5's owner = KM-4 (the mixing phase), and
  FORWARD-2 will move `AC-5 → KM-4` into `unpendedACs` when it un-pends — retargeting
  the owner to FORWARD-2 would collide with AC-14 and break the bijection test.
- **Gates (all green, first full run — fix passes 0/3):** `dart analyze` clean;
  `dart test` 108 pass / 24 skip / 0 fail; coverage PASS (`mixing.dart` 16/16 lines,
  line-only metric; barrel no executable lines); acceptance default green
  (10 pass / 24 pending — AC-5 still pending, as intended).
- **No grade gate** (enabler, no un-pended AC test).
- **Unit tests:** new `test/mixing_test.dart` — independent double-precision `refMix`
  reference; shape; per-wavelength weighted-sum match; single-paint identity; K and S
  mixed independently (rejects a ratio-only mix); **self-mix idempotence** at four
  ratios + three-way split == whole (AC-5); **order independence** under permutation
  (AC-5); weights used as given, not normalised (summing to 2 doubles the result;
  zero-weight contributes nothing — pins the no-normalisation contract so AC-14 stays
  meaningful); empty-list and off-grid guards throw.
- **No augmentations** assigned to or newly enabled by this phase.
- Tokens: 3.94M · Time: 7m 52s (8m 09s) — see ledger.

### Checkpoint / Handoff

- **Frozen interface:** `mixTwoConstant(List<MixComponent> components) → KmMix`
  with `MixComponent = ({Spectrum k, Spectrum s, double weight})` and
  `KmMix = ({Spectrum k, Spectrum s})`. Elementwise `Kmix = Σ vᵢ·Kᵢ`,
  `Smix = Σ vᵢ·Sᵢ`; output spectra are `CanonicalGrid.bins` long. Pure weighted
  sum — **does not normalise** weights, and does not form `K/S` (that is KM-2's
  `kmReflectance` input). Throws `ArgumentError` on empty components or an off-grid
  spectrum. Exported via the barrel.
- **Verification commands (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"`
  first. Analyze `dart analyze`; unit `dart test`; coverage
  `bash tool/coverage_gate.sh <BASE>` (line-only); acceptance default
  `dart test test/acceptance`; run-pending `PIGMENT_KM_RUN_PENDING=true dart test
  test/acceptance`.
- **Next — FORWARD-2 (`CustomKmEngine`, AC-14 un-pend + AC-5 un-pend):** the forward
  path normalises `Map<String,double>` volumes to Σ1 (AC-14), looks up each paint's
  K/S, builds `MixComponent`s, calls `mixTwoConstant`, then `K/S = Kmix/Smix` →
  `kmReflectance` (KM-2) → `saundersonToMeasured` (KM-3) → spectrum→colour (COLOR).
  FORWARD-2 un-pends **AC-5** (self-mix/order-independence at the colour level via
  `forward`) recording `AC-5 → KM-4` in `unpendedACs`, and **AC-14** recording
  `AC-14 → FORWARD-2`. Drop the matching rows in `backends_stub_test.dart`.
- **Known gaps:** none. KM module complete (KM-2/3/4 ✅).
