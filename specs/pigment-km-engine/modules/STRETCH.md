# Module STRETCH — glazing + metamerism (optional S6)

**Status:** Not started — deferred behind G-7
**Feature:** [MASTER_PLAN_FOR_FEATURE.md](../MASTER_PLAN_FOR_FEATURE.md)
**Owns (files/areas):** `lib/src/stretch/glazing.dart` (finite-thickness layering), `lib/src/stretch/metamerism.dart` (multi-illuminant index)
**Depends on:** FORWARD, COLOR · **Blocks:** SIGNOFF-1 (only if G-7 enables STRETCH)

## Dashboard

| Phase | Kind | Target AC | Status | Tokens | Time |
|---|---|---|---|---|---|
| 2 (STRETCH-2) | behavior | AC-26 | ⬜ Todo (G-7) | | |
| 3 (STRETCH-3) | behavior | AC-27 | ⬜ Todo (G-7) | | |

## Interface reconciliation

Design §3.4 (finite-thickness layering — the opaque dataset doesn't give transparent-glaze params, so this uses assumed film thickness, a known caveat) and §9 (metamerism across D65 + a warm studio illuminant). `@stretch`-tagged scenarios are excluded from the default acceptance run until G-7. "Only if value is proven" (design §8).

## Open gates
- **G-7** (decision) blocks both phases: confirm STRETCH scope before building it.
- **G-2** blocks all behavior.

## Phase 2 — STRETCH-2: finite-thickness glazing (AC-26)

- **Kind:** behavior · **Target AC:** AC-26 (full) · **Depends on:** FORWARD-4 (G-7) · **Blocks:** —
- **Files:** `glazing.dart`
- **Tasks:** implement the §3.4 layering equation (glaze over ground Rg at thickness X); verify R→opaque as X→∞ (control).
- **Exit criteria:** analyze clean; 100% touched; layering eqn correct; large-X ≈ opaque form.
- **Acceptance gate:** un-pend AC-26; `TestAC26_Glazing` (@stretch) green.

### Result · Checkpoint  <!-- filled on completion -->

## Phase 3 — STRETCH-3: metamerism index (AC-27)

- **Kind:** behavior · **Target AC:** AC-27 (full) · **Depends on:** COLOR-2, FORWARD-2 (G-7) · **Blocks:** SIGNOFF-1
- **Files:** `metamerism.dart`
- **Tasks:** evaluate recipes under D65 + a warm studio illuminant; assign a metamerism index; warn on illuminant-fragile matches (design §9).
- **Exit criteria:** analyze clean; 100% touched; the degrading recipe gets the higher index; warning fires.
- **Acceptance gate:** un-pend AC-27; `TestAC27_Metamerism` (@stretch) green.

### Result · Checkpoint  <!-- filled on completion -->
