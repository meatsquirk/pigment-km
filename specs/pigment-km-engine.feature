# APPROVED 2026-10-16 by Matt Quirk (gate G-1) — spec accepted as-is; scaffolding unblocked.
# Feature spec — pigment_km: measured-pigment Kubelka–Munk mixing engine
#
# Status: APPROVED 2026-10-16 (G-1). Was DRAFT, derived 2026-10-15 from the design doc.
#
# Derivation: this spec was derived (2026-10-15) by Claude from
#   Nuance/docs/custom-mixing-engine-design.md (the "B2" in-house measured-pigment engine
#   design — physics §3, datasets §4, forward/inverse §6, tuning §7, staged plan §8,
#   licensing §13) and Nuance/docs/paint-color-app-solution-intent.md (D3, D6, D7, D9;
#   "Mixing engine: options"; "Non-functional requirements and accuracy targets").
#   Each scenario cites its source. The exit gates of design-doc §8 (S0–S6) are the
#   acceptance criteria; the solution-intent ΔE00 targets are the numeric thresholds.
#
# Deliverable: a standalone open-source Dart package `pigment_km`, MIT-licensed, with
#   attribution to the source research (design §13). The Nuance app later consumes it
#   behind its existing `MixingEngine` interface (lib/recipes/engine/mixing_engine.dart)
#   via a thin adapter — that adapter is Nuance's work, not this package's.
#
# Canonical internal grid: 400–700 nm @ 10 nm = 31 bins (design §2, §4.3). Every dataset
#   is resampled onto it at ingest. Spectrum = Float32List length 31.
#
# Media in scope: acrylic (Golden Heavy Body, RIT Artist Paint Spectral Database — Okumura
#   2005; Berns 2022) and oil (Old Holland, MPI dataset — Asadi, Babaei & Seidel). Acrylic
#   is brought up end-to-end first (owner's medium; permission granted 2026-10-15); oil
#   follows (MPI is CC BY 4.0, already clear). A recipe never spans media.

Feature: Measured-pigment Kubelka–Munk mixing engine
  As the mixing-engine authority behind the swappable MixingEngine interface (SI D3),
  the library predicts and solves paint mixtures from real measured pigment K/S data,
  so mixes behave like the painter's actual tubes and every recipe carries honest
  provenance — never a fabricated match.

  # ───────────────────────── COLOR: spectrum → colour backend (design §3.5, §2) ─────────────────────────

  # Source: design §3.5 (reuse Spectral.js spectrum→XYZ→sRGB). Reference: perfect diffuser
  #   R(λ)=1 under D65 → XYZ of the D65 white point; a published pigment reflectance → its
  #   catalogued sRGB/XYZ.
  Scenario: A reflectance spectrum converts to its expected colour
    Given a reflectance spectrum on the canonical 31-bin grid with a known published colour
    When the colour backend converts it with the D65 illuminant and CIE 1931 observer
    Then the resulting CIE XYZ and sRGB match the published values within ΔE00 ≤ 1

  # Source: design §2 ("OKLab/OKLCh gamut mapping ... keeps outputs in-gamut without clipping").
  Scenario: Colours outside sRGB are gamut-mapped, not clipped
    Given a predicted colour whose chroma falls outside the sRGB gamut
    When the backend maps it into gamut
    Then the returned sRGB is inside the gamut with its hue and lightness preserved
    And no channel is hard-clipped at 0 or 1 to fake the match

  # ───────────────────────── KM: the physics (design §3) ─────────────────────────

  # Source: design §3.1 (KM reflectance and its inverse f(R)).
  Scenario: Kubelka–Munk reflectance and K/S round-trip
    Given a per-wavelength K/S ratio
    When reflectance is computed from it and then the K–M function is applied to that reflectance
    Then the recovered K/S equals the original within floating-point tolerance

  # Source: design §3.2 (Saunderson; k1,k2 per medium — oil differs from acrylic).
  Scenario: Saunderson correction round-trips per medium
    Given an internal reflectance and a medium's documented k1 and k2 constants
    When it is converted to measured reflectance and back to internal
    Then the recovered internal reflectance equals the original within tolerance
    And acrylic and oil use their own distinct k1,k2 constants

  # Source: design §3.3 (two-constant mixing) + §5 (concentration = volume fraction).
  Scenario: Two-constant mixing is linear and order-independent
    Given two or more paints each with its own K and S spectra and volume fractions summing to 1
    When the mixture K and S are formed as the volume-weighted sums of the parts
    Then mixing a paint with only itself reproduces that paint's own colour at any ratio
    And permuting the order of the components does not change the predicted colour

  # ───────────────────────── DATA: datasets and ingestion (design §4, §13; SI D6/D9) ─────────────────────────

  # Source: design §4 + §10 (Pigment type) + SI D6 (build artifact), D9 (provenance + source ref).
  Scenario: The pigment table ships as a medium-tagged build artifact
    Given the shipped pigment-table build artifact
    When a medium's pigment table is loaded
    Then every paint exposes K and S on the canonical 31-bin grid, a pigment index, an opacity, a provenance tier, and an internal source reference
    And every paint is tagged with exactly one medium

  # Source: design §4.1 step 3 — the ingest round-trip gate (the data is wrong if this fails).
  Scenario: Every ingested paint round-trips to its published colour
    Given the ingested acrylic (Golden/RIT) pigment table
    When each paint's K and S are rendered to its opaque reflectance and then to colour
    Then the rendered colour reproduces the dataset's published colour for that paint within ΔE00 ≤ 0.5

  # Source: design §2, §4.3 — resample native grids onto the canonical grid at ingest.
  Scenario: Native dataset grids are resampled onto the canonical grid
    Given a dataset measured on its native wavelength grid (acrylic 380–730 nm, oil 400–700 nm)
    When it is ingested
    Then its spectra are resampled onto the canonical 400–700 nm @ 10 nm grid
    And spectra from different media are directly comparable on that one grid

  # Source: design §4.2 — oil K,S fit from the published mixtures (the dataset self-validates).
  Scenario: Oil K and S are fit from the published mixtures and validated on held-out ones
    Given the MPI oil pure-paint and mixture reflectances with their published volume ratios
    When K and S per paint are fit per wavelength by non-negative least squares on a training subset
    Then the fit predicts the held-out mixtures' colours within ΔE00 ≤ 5
    And the fit coefficients are non-negative at every wavelength

  # Source: design §4.4 — masstone–tint derivation (the hook for user-measured tubes).
  Scenario: K and S are derived from a masstone and tint series
    Given a pigment's masstone reflectance and a series of tints with white at known concentrations
    When K and S are derived per wavelength by least squares across the tint series
    Then the derived K and S reproduce every tint's measured reflectance within tolerance

  # Source: design §13 (licensing + attribution), SI D9. Permission for Golden/RIT granted
  #   by Roy Berns on 2026-10-15; MPI oil is CC BY 4.0.
  Scenario: Shipped data carries its licence attribution and correct provenance
    Given the shipped data artifact and the package's licence files
    When the package and its data notices are inspected
    Then the package is licensed MIT
    And the MPI oil data carries its CC BY 4.0 attribution naming Asadi, Babaei & Seidel and stating the changes made
    And the Golden/RIT acrylic data carries the attribution agreed under the granted permission
    And each paint's provenance tier reflects the source it came from

  # ───────────────────────── FORWARD: the forward engine (design §6.1) ─────────────────────────

  # Source: design §6.1 — forward(paints+ratios)→colour, exact.
  Scenario: The forward model predicts a known mixture's colour
    Given a mixture of measured paints at known volume fractions with a published measured colour
    When the engine predicts the mixture's colour
    Then the prediction matches the dataset's measured colour within ΔE00 ≤ 5

  # Source: design §1 + §7 — real pigments gray/desaturate where synthetic primaries stay vibrant.
  Scenario: Mixing two real pigments desaturates the way real paint does
    Given two chromatic measured paints of different hues
    When they are mixed in equal volume
    Then the mixture's chroma is lower than a naive linear-RGB blend of the same two colours

  # Source: design §5 — volumes normalized; finished-paint concentration model.
  Scenario: Volumes are normalized before mixing
    Given parts-by-volume that do not sum to 1
    When the engine predicts the mixture's colour
    Then the parts are normalized to sum 1 and map directly to the concentration weights

  # ───────────────────────── SOLVER: the inverse solver (design §6.2; SI NFR) ─────────────────────────

  # Source: design §6.2 — top-K by ΔE00, parts-by-volume, prefer fewer paints.
  Scenario: The inverse solver returns ranked recipes preferring fewer paints
    Given a target colour and a declared palette of paints
    When the solver searches for recipes
    Then it returns up to the requested number of recipes ordered best-first by ΔE00
    And when two recipes tie on ΔE00 the one using fewer paints is ranked first
    And each recipe is expressed as parts-by-volume summing to 1

  # Source: design §6.2 — palette is a hard constraint (SI "recipes solved only against the user's palette").
  Scenario: Recipes use only paints in the declared palette
    Given a target colour and a declared palette
    When the solver returns recipes
    Then every paint in every returned recipe is a member of that palette

  # Source: SI NFR ("Recipe prediction vs physically mixed swatch ΔE00 ≤ 5 for in-gamut targets").
  Scenario: An in-gamut target is matched within the recipe accuracy target
    Given a target colour that is reachable within the palette's gamut
    When the solver returns its best recipe
    Then the best recipe's ΔE00 to the target is at most 5

  # Source: design §6.2 + SI fixed intent ("out-of-gamut is stated, not hidden; never a false recipe").
  Scenario: An out-of-gamut target is flagged, never faked
    Given a target colour that no mixture of the palette can reach within the in-gamut ceiling
    When the solver returns its best recipe
    Then the recipe is flagged out-of-gamut and carries its honest ΔE00 distance
    And the engine never reports it as a match

  # Source: design §4.3 — the cross-medium hard constraint.
  Scenario: A single recipe never spans media
    Given a palette containing both acrylic and oil paints
    When the solver returns recipes for a target
    Then every returned recipe uses paints of exactly one medium
    And the solver searches each medium's paints separately

  # Source: SI NFR ("recipe search returns the top 3–5 candidates within ~1–2 s on target hardware").
  Scenario: The solver returns within the performance budget
    Given a declared palette of about 15 paints
    When the solver is asked for the top three recipes for a target
    Then it returns within about 1 to 2 seconds

  # ───────────────────────── TUNE: natural, muted colour (design §7) ─────────────────────────

  # Source: design §7 lever 1 — a curated limited real-pigment palette cannot go neon.
  Scenario: The curated default palette cannot produce neon mixes
    Given the curated naturalistic default palette for a medium
    When any mixture of that palette is predicted
    Then no predicted mixture exceeds the naturalistic chroma ceiling for that palette
    And a muted earth target is reachable within the recipe accuracy target

  # Source: design §7 lever 2 — chromaPenalty breaks ties toward lower chroma.
  Scenario: The chroma penalty breaks ΔE00 ties toward the more muted recipe
    Given two recipes that tie on ΔE00 to a target
    When the solver ranks them with the natural-colour chroma penalty enabled
    Then the lower-chroma recipe is ranked first
    And with the penalty disabled the ranking depends on ΔE00 alone

  # Source: design §7 lever 3 — per-medium wet→dry transform (SI open decision #6).
  Scenario: The wet/dry toggle shifts the prediction by the medium's documented offset
    Given a mixture predicted in its wet state
    When the same mixture is predicted in its dry state
    Then the dry colour differs from the wet colour by the medium's documented drying offset
    And acrylic's dry colour is darker and hue-shifted relative to its wet colour

  # ───────────────────────── PROD: provenance, interface, productionizing (design §8 S5; SI D3/D9) ─────────────────────────

  # Source: SI D9 provenance tiers; design §8 S5 ("recipes carry correct provenance").
  Scenario: Recipes from measured data are labelled Calculated, and user tubes Measured
    Given a recipe solved from the shipped measured pigment data
    When its provenance is read
    Then it is Calculated — not Measured and not Estimated
    And a recipe using a paint whose K,S the user measured from their own tube is Measured

  # Source: design §8 S0/S5 + SI D3 — the interface is stable and A/B-swappable.
  Scenario: The measured-pigment engine and a baseline engine are interchangeable
    Given a target and palette solved once by the measured-pigment engine and once by the single-constant baseline engine
    When both are driven through the same MixingEngine interface
    Then both return recipes through the identical interface with no caller change
    And the A/B harness reports each engine's ΔE00 on the same swatch set

  # ───────────────────────── STRETCH: optional S6 (design §3.4, §9) — gated behind G-7 ─────────────────────────

  # Source: design §3.4 — finite-thickness glazing (stretch; opaque dataset caveat noted).
  @stretch
  Scenario: A glaze over a ground predicts via the finite-thickness layering equation
    Given a mixture glazed at a finite film thickness over a ground of known reflectance
    When its layered reflectance is computed
    Then it follows the finite-thickness Kubelka–Munk layering equation
    And as the thickness grows large the result approaches the opaque-form reflectance

  # Source: design §9 — metamerism across illuminants (stretch).
  @stretch
  Scenario: Illuminant-fragile matches are flagged with a metamerism index
    Given two recipes that match a target equally under D65
    When they are evaluated under D65 and a warm studio illuminant
    Then the recipe whose match degrades under the studio illuminant is assigned a higher metamerism index
    And the engine warns that that match is illuminant-fragile
