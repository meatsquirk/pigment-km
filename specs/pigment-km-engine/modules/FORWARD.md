# Module FORWARD — the forward engine

**Status:** In progress — FORWARD-2 ✅, FORWARD-4 ✅ (AC-13); only FORWARD-3 left, gated on G-3/G-4 (real measured mixtures)
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/engine/custom_km_engine.dart` (`forward`, `reflectanceOf`), `lib/src/engine/forward.dart`
**Depends on:** COLOR, KM, DATA · **Blocks:** SOLVER, STRETCH

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 2 (FORWARD-2) | behavior | AC-14, AC-5 | ✅ Done | 11.23M | 17m 53s (39m 37s) |
| 3 (FORWARD-3) | behavior | AC-12 | ⬜ Todo (G-3/G-4) | | |
| 4 (FORWARD-4) | behavior | AC-13 | ✅ Done | 4.82M | 9m 00s (9m 00s) |

## Interface reconciliation

`forward(mix)` composes KM-4 mixing → KM-2 reflectance → KM-3 Saunderson(medium) → COLOR spectrum→colour (design §6.1). FORWARD-2 (normalization) is the enabler the fidelity and desaturation phases build on, so it comes first.

## Open gates
- **G-2** blocks all behavior. **G-3/G-4** block FORWARD-3's measured-mixture fidelity (synthetic until then).

## Phase 2 — FORWARD-2: normalize + forward pipeline (AC-14 + AC-5, enabler)

- **Kind:** behavior · **Target AC:** AC-14 (full) **+ AC-5** (moved here from KM-4 per G-2 2026-10-16 — AC-5's colour-level Then runs through `CustomKmEngine.forward`, which this phase makes real); also makes `forward`/`reflectanceOf` real for later Givens
- **Depends on:** COLOR-3, KM-4, DATA-1 · **Blocks:** FORWARD-3, FORWARD-4, SOLVER-2
- **Files:** `forward.dart`, `custom_km_engine.dart`
- **Tasks:** normalize parts to Σ1; assemble the forward pipeline (composes KM-4 mixing → KM-2 reflectance → KM-3 Saunderson → COLOR spectrum→colour); implement `reflectanceOf`.
- **Exit criteria:** analyze clean; 100% touched; unnormalized == normalized result; self-mix==pure colour + order-independent mix (AC-5).
- **Acceptance gate:** un-pend AC-14 **and AC-5**; `TestAC14_Normalize` and `TestAC05_TwoConstantMix` green.

### Result

Built the forward model (design §6.1). New `lib/src/engine/forward.dart`:
`normalizeParts(mix)` (parts-by-volume → concentration weights summing to 1, §5),
`forwardReflectance(mix, resolve)` (the pipeline — normalize → resolve ids →
`mixTwoConstant` → per-λ `K/S` → `kmReflectance` internal R∞ →
`saundersonToMeasured(configForMedium(medium))` measured reflectance) and
`forwardColour = spectrumToColour(forwardReflectance(...))`. `custom_km_engine.dart`
wires `forward`/`reflectanceOf` to these with a static `_resolve` that looks an id
up across both media tables and throws `ArgumentError` on an unknown id; the
pipeline throws `ArgumentError` on an empty mix, a non-positive volume sum, or a
mixture spanning media (the `MixingEngine` "never spans media" invariant). `inverse`
stays a SOLVER stub.

- **Gates (all green):** `dart analyze` clean; unit `dart test` 115 pass / 22 skip
  / 0 fail; coverage PASS — `forward.dart` 28/28, `custom_km_engine.dart` 11/11
  lines (line-only metric; every branch — acrylic/oil/not-found resolution, media
  span, empty, zero-sum — exercised by added `engine_test.dart` cases); acceptance
  default green (AC-5 + AC-14 un-pended & green; 22 ACs still pending);
  `TestAC05_TwoConstantMix` and `TestAC14_Normalize` green.
- **Grade gate:** fresh independent adversarial subagent re-graded every un-pended
  AC test (AC-1/3/4/5/14). First pass: **AC-14 = B** (G5/G4) — the opaque
  two-constant forward is scale-invariant in the volume weights
  (`K/S = Σv·K/Σv·S`), so a non-normalizing engine gives bit-identical colour; the
  old colour-only AC-14 could not reject its named raw-weight impl. **Fixed in-phase
  (fix pass 1/3):** exposed `normalizeParts` publicly (the spec step names "parts
  normalized to sum 1" as the observable) and rewrote AC-14 to assert it directly
  (Σ=1, {2/3,1/3}, ratio preserved, ≠ raw 2.0 → rejects the identity map), keeping
  scale-invariance as an honestly-labelled consistency property. A second fresh
  grader re-graded **AC-14 = A**. Final: **5 A** (AC-1/3/4 re-confirmed; AC-5 live A;
  AC-14 B→A). Grid: `behavior-test-completeness-pigment-km-engine.md`.
- **Un-pend:** deleted AC-5 and AC-14 from `pendingACs` (`pending.dart`); added
  `AC-5: KM-4` and `AC-14: FORWARD-2` to `unpendedACs` (`pending_gate_test.dart`) —
  the 27↔27 bijection keeps AC-5's owner = KM-4 (the mixing phase), AC-14's =
  FORWARD-2, so owners stay distinct.
- **Other tests:** `engine_test.dart` rewritten (forward model now live — forward
  of a real paint returns a `ColourValue`, inverse still throws; + oil-id
  resolution, unknown-id, media-span, empty, zero-sum guard cases). Acceptance
  `smoke_test.dart`'s forward case updated from "throws UnimplementedError" to the
  real end-to-end wiring proof (reflectance physical in 0..1, flat-spectrum white →
  near-neutral low-chroma colour).
- **Augmentations:** none assigned to FORWARD-2; the AC-14 fix strengthens AC-14's
  own test only (G6). No already-green neighbour can assert more from this phase.
- Tokens: 11.23M · Time: 17m 53s active (39m 37s wall) — see ledger.

### Checkpoint / Handoff

- **Frozen interface:** `CustomKmEngine().forward(Map<String,double>)` → `ColourValue`
  and `.reflectanceOf(...)` → measured-reflectance `Spectrum` (the read endpoint) are
  live; `forward == spectrumToColour(reflectanceOf)`. Public `normalizeParts(mix)` →
  concentration weights summing to 1 (exported via the barrel, `show normalizeParts`).
  Internal `forwardReflectance`/`forwardColour(mix, PigmentResolver)` in `forward.dart`
  are not exported. A mix's medium is inferred from its paints; a cross-medium mix,
  an unknown id, an empty mix and a non-positive sum all throw `ArgumentError`.
- **Verification commands (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"`
  first. Analyze `dart analyze`; unit `dart test`; coverage
  `bash tool/coverage_gate.sh <BASE>` (line-only); acceptance default
  `dart test test/acceptance`; run-pending `PIGMENT_KM_RUN_PENDING=true dart test
  test/acceptance`. Un-pend = delete the AC row in `pending.dart` **and** add it to
  `unpendedACs` in `pending_gate_test.dart` (the engine stub rows live in
  `engine_test.dart`, not `backends_stub_test.dart`).
- **Scale-invariance (carry-forward):** the opaque two-constant forward depends on
  volumes only through the ratio `K/S = Σv·K/Σv·S`, so normalization is a no-op on
  the predicted *colour* — only `normalizeParts` observes it. Any later concern that
  must distinguish absolute concentration (e.g. STRETCH glazing / finite-thickness)
  needs its own non-opaque observable; don't rely on `forward` to surface it.
- **Next phases off FORWARD-2:** **FORWARD-4** (AC-13 desaturation, startable now —
  chroma(KM mix) < chroma(linear-RGB blend) for two chromatic synthetic pigments;
  `forward` likely needs no change, test-only). **FORWARD-3** (AC-12 forward fidelity)
  stays gated on G-3/G-4 (real measured mixtures). **SOLVER-2** (AC-16 palette-only)
  is now unblocked (depended on FORWARD-2).
- **Known gaps:** none for AC-5/AC-14 (behaviour complete). Saunderson constants
  remain provisional pending G-5 (carried from KM-3).

## Phase 3 — FORWARD-3: measured-mixture fidelity (AC-12) — needs G-3/G-4

- **Kind:** behavior · **Target AC:** AC-12 (full)
- **Depends on:** FORWARD-2, DATA-5 (acrylic) / DATA-6 (oil) · **Blocks:** —
- **Files:** `custom_km_engine.dart` (tolerance/validation only)
- **Tasks:** validate `forward` against real measured mixtures (Phase-0.5 S2 gate, design §8); record the ΔE00 distribution.
- **Exit criteria:** analyze clean; 100% touched; ΔE00 ≤ 5 on the measured mixtures.
- **Acceptance gate:** un-pend AC-12; `TestAC12_ForwardFidelity` green against real data; **augment** from the synthetic placeholder.

### Result · Checkpoint  <!-- filled on completion -->

## Phase 4 — FORWARD-4: natural desaturation (AC-13)

- **Kind:** behavior · **Target AC:** AC-13 (full)
- **Depends on:** FORWARD-2 · **Blocks:** STRETCH-2
- **Files:** `forward.dart` (no change expected) + test
- **Tasks:** demonstrate chroma(KM mix) < chroma(linear-RGB blend) for two chromatic pigments (the natural-colour property, design §1/§7).
- **Exit criteria:** analyze clean; 100% touched; property holds on synthetic and (post-data) real pigments.
- **Acceptance gate:** un-pend AC-13; `TestAC13_Desaturation` green.

### Result

**No production code needed — green at baseline.** The natural-desaturation property
was already satisfied by the live `forward` pipeline (FORWARD-2) over the
hue-faithful fixture (DATA-8): KM two-constant mixing is subtractive, so an
equal-volume mix of two chromatic paints greys out where a naive per-channel sRGB
midpoint stays vibrant. FORWARD-4 is therefore the sanctioned *green-at-baseline*
un-pend (acceptance-suite.md § *Red baseline*): the behaviour phase still runs to
un-pend AC-13, keep it green and re-grade. The pre-written `TestAC13_Desaturation`
(ITEST-3) already discriminates against an RGB-space-blending engine; checked and
found strong (see grade gate), so no strengthening was owed.

- **Measured property (throwaway probe, not committed):** `kmMix.oklch.c = 0.01618`
  vs naive sRGB-midpoint `rgbBlendChroma = 0.04849` — gap **0.0323**, ratio **0.334**
  (≈3× desaturation). Pure paints post-DATA-8: phthalo_blue c=0.092 h≈275°,
  naphthol_red c=0.078 h≈28°, Δh≈113°; both Givens hold with wide margin.
- **Un-pend:** deleted `AC-13` from `pendingACs` (`pending.dart`); added
  `AC-13: FORWARD-4` to `unpendedACs` (`pending_gate_test.dart`). No engine stub to
  remove (`forward` live since FORWARD-2). The 27↔27 bijection holds (11 un-pended,
  16 pending).
- **Gates (all green):** `dart analyze` clean; full unit `dart test` **+137 ~16**,
  0 fail; acceptance default **+19 ~16** (AC-13 now executes live, no longer skipped);
  run-pending red baseline **+22 −13** — the 13 failing are exactly the still-pending
  later-phase ACs (AC-7/8/9/10/11/12/21/22/23/24/25/26/27), each on its
  Then/precondition; AC-13 passes. Coverage gate: no `lib/` file touched →
  *no touched library files — OK* (and the populated path still passes, forward.dart
  28/28).
- **Grade gate:** fresh independent adversarial subagent re-graded **all 11**
  un-pended AC tests (AC-1/2/3/4/5/13/14/15/16/18/19) → **11 A, 0 B, 0 fixes owed**.
  AC-13 confirmed genuinely A: the prior standing "strict `<`" flag is now quantified
  and discharged (3× gap, noise-free; library `linearSrgbToOklch` shares byte-identical
  Ottosson constants with the harness, so an sRGB-midpoint engine lands exactly on the
  boundary and fails the strict `<`). The other 10 run byte-identical code/fixture and
  re-confirm their DATA-8 A grades. Grid: `behavior-test-completeness-pigment-km-engine.md`.
- **Augmentations:** none assigned to FORWARD-4; no already-green neighbour can assert
  more from this test-only un-pend (G6).
- **Tooling fix:** `tool/coverage_gate.sh` had a latent `set -u` bug — iterating
  `"${changed[@]}"` errors on an empty array (any phase touching no `lib/` file, like
  this one), never reaching its own "no touched library files — OK" path. Fixed with
  the empty-array-safe expansion `${changed[@]+"${changed[@]}"}`; the populated path
  is unchanged (verified: `--files lib/src/engine/forward.dart` → 28/28 PASS).
- Tokens: 4.82M · Time: 9m 00s active (9m 00s wall) — see ledger.

### Checkpoint / Handoff

- **Frozen interface:** unchanged from FORWARD-2 — `CustomKmEngine().forward(mix)` →
  `ColourValue`, `.reflectanceOf(mix)` → measured `Spectrum`, public
  `normalizeParts(mix)`. FORWARD-4 added no surface.
- **Verification commands (reuse):** `export PATH="$HOME/development/flutter/bin:$PATH"`
  first. `dart analyze`; unit `dart test`; coverage `bash tool/coverage_gate.sh <BASE>`
  (line-only; now empty-array-safe); acceptance default `dart test test/acceptance`;
  run-pending `PIGMENT_KM_RUN_PENDING=true dart test test/acceptance`. Un-pend = delete
  the AC row in `pending.dart` **and** add it to `unpendedACs` in `pending_gate_test.dart`.
- **Known gaps:** none for AC-13 on synthetic pigments (behaviour complete). The
  exit criterion's "post-data real pigments" clause folds into FORWARD-3's real
  measured-mixture validation (G-3/G-4) — the desaturation property is physical to KM
  mixing, so it will hold on real K/S too; no separate AC-13 augmentation is owed.
- **Next phases off FORWARD-4:** **STRETCH-2** (AC-26 glazing) lists FORWARD-4 as a
  dependency but remains gated on **G-7** (STRETCH scope). FORWARD module now has only
  **FORWARD-3** (AC-12) left, gated on **G-3/G-4** (real measured mixtures).
