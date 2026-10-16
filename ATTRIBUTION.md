# Attribution

`pigment_km`'s **source code** is licensed under the MIT License ([LICENSE](LICENSE)).

The measured-pigment data the library ships (or is designed to ship) is **not**
covered by the MIT License and keeps its own terms. The authoritative, legally
operative notices live in [NOTICE](NOTICE); this file is the human-readable
companion and maps each data source to the [`Provenance`] tier the paints
derived from it carry.

> **Scaffold.** DATA-1 ships only the **synthetic placeholder** table (design
> decision D-7). The real-dataset rows below are finalized when the licensed
> data lands — the acrylic wording under the granted permission in **DATA-7**
> (gate **G-3**), the oil rows in **DATA-6** (gate **G-4**).

## Data sources

### Synthetic placeholder (shipped today)

- **Files:** `assets/pigments/synthetic_acrylic.json`, `assets/pigments/synthetic_oil.json`
- **What it is:** a tiny, hand-specified stand-in table so the engine and tests
  run before the licensed data lands. The values are invented, not measured.
- **Provenance:** every synthetic paint is tagged `estimated`, and its
  `sourceRef` begins `synthetic:`. Nothing synthetic is ever labelled measured or
  calculated.

### Golden Heavy Body acrylics — RIT Artist Paint Spectral Database *(pending G-3)*

- **Source:** Okumura (2005); Berns (2022). Munsell Color Science Laboratory,
  Rochester Institute of Technology.
- **Terms:** used **by permission** of Prof. Roy S. Berns (granted 2026-10-15),
  with attribution — **not** under the MIT license, and **not** an open-data
  grant. Third parties must obtain their own permission from RIT / MCSL.
- **Provenance:** paints derived from this data are tagged `calculated`
  (modelled from measured pigment data). A user's own measured tube is `measured`.
- Exact citation text and the agreed attribution wording are carried in
  [NOTICE](NOTICE) and finalized in DATA-7.

### Old Holland oils — MPI multispectral paint dataset *(pending G-4)*

- **Source:** Asadi Shahmirzadi, Babaei & Seidel, *A Multispectral Dataset of
  Oil and Watercolor Paints*, IS&T Electronic Imaging, 2020.
- **Terms:** **CC BY 4.0** (https://creativecommons.org/licenses/by/4.0/).
- **Changes:** reflectances resampled onto this library's canonical 400–700 nm
  @ 10 nm grid and used to derive two-constant Kubelka–Munk K/S coefficients.
- **Provenance:** paints fit from this data are tagged `calculated`.

[`Provenance`]: lib/src/types/provenance.dart
