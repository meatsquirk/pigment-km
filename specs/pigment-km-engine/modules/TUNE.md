# Module TUNE — natural, muted colour

**Status:** Not started
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/tune/default_palettes.dart` (curated naturalistic per-medium palettes), `lib/src/tune/chroma_penalty.dart`, `lib/src/tune/wet_dry.dart`
**Depends on:** SOLVER, DATA · **Blocks:** SIGNOFF-1

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 2 (TUNE-2) | behavior | AC-22 | ⬜ Todo | | |
| 3 (TUNE-3) | behavior | AC-21 | ⬜ Todo (G-3 real palette) | | |
| 4 (TUNE-4) | behavior | AC-23 | ⬜ Todo | | |

## Interface reconciliation

Design §7: curated limited real-pigment palette (lever 1, biggest), `chromaPenalty` λ_natural tie-break (lever 2, D-10), per-medium wet→dry transform (lever 3, D-12). No sRGB desaturation filter — naturalness is physics+palette.

## Open gates
- **G-2** blocks all behavior. **G-3** gives the real acrylic curated palette (synthetic until then).

## Phase 2 — TUNE-2: chroma penalty tie-break (AC-22)

- **Kind:** behavior · **Target AC:** AC-22 (full) · **Depends on:** SOLVER-6 · **Blocks:** —
- **Files:** `chroma_penalty.dart`, `inverse.dart` (hook)
- **Tasks:** add `λ_natural·C*(mix)` as a small tie-break regularizer, off by default in raw ΔE00 ranking.
- **Exit criteria:** analyze clean; 100% touched; penalty-on prefers lower chroma on a tie; penalty-off unchanged (control).
- **Acceptance gate:** un-pend AC-22; `TestAC22_ChromaPenalty` green.

### Result · Checkpoint  <!-- filled on completion -->

## Phase 3 — TUNE-3: curated default palette (AC-21) — real palette needs G-3

- **Kind:** behavior · **Target AC:** AC-21 (full) · **Depends on:** SOLVER-6, DATA-5 · **Blocks:** —
- **Files:** `default_palettes.dart`
- **Tasks:** ship the Zorn-style earth-forward acrylic default (design §7); prove no mixture exceeds the chroma ceiling, a muted target solves ≤ 5, a neon target returns out-of-gamut.
- **Exit criteria:** analyze clean; 100% touched; neon-impossible property holds.
- **Acceptance gate:** un-pend AC-21; `TestAC21_NoNeon` green; **augment** from the synthetic palette to the real one when G-3 lands.

### Result · Checkpoint  <!-- filled on completion -->

## Phase 4 — TUNE-4: wet/dry transform (AC-23)

- **Kind:** behavior · **Target AC:** AC-23 (full) · **Depends on:** SOLVER-6 · **Blocks:** SIGNOFF-1
- **Files:** `wet_dry.dart`, `custom_km_engine.dart` (toggle)
- **Tasks:** per-medium wet→dry offset (D-12, default wet); re-render colour without re-solving (parts & ΔE00 unchanged); acrylic dry darker + hue-shifted.
- **Exit criteria:** analyze clean; 100% touched; dry≠wet by the documented offset; parts unchanged.
- **Acceptance gate:** un-pend AC-23; `TestAC23_WetDry` green.

### Result · Checkpoint  <!-- filled on completion -->
