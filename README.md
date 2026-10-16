# pigment_km

**Measured-pigment, two-constant Kubelka–Munk colour mixing for Dart.**

`pigment_km` predicts and solves paint mixtures from *real measured pigment data* —
per-wavelength absorption **K** and scattering **S** spectra — using two-constant
Kubelka–Munk theory with the Saunderson surface correction. Because it mixes real
pigments rather than idealized synthetic primaries, mixtures gray and shift hue the way
actual paint does, and earth tones come out faithful instead of digitally vivid.

It is designed as the measured-pigment engine behind a swappable `MixingEngine` interface:
a **forward** model (paints + parts-by-volume → colour) and an **inverse** solver (a target
colour → the best recipes from the painter's own palette, by ΔE00), with every recipe
carrying an honest provenance label and an explicit out-of-gamut signal — never a
fabricated match.

The motivating application is an accessibility tool for artists with colour vision
deficiency: formulating mixtures from a phone when matching colour by eye is unreliable.

> **Status: early development.** The design and full phase plan live under
> [`specs/`](specs/). The public API shown below is the target shape and is still being
> built; pigment datasets are integrated behind feature gates. Not yet published to pub.dev.

## How it works

- **One canonical spectral grid:** 400–700 nm at 10 nm (31 bins). Every dataset is
  resampled onto it at ingest, so spectra from different media are directly comparable.
- **Two-constant Kubelka–Munk:** absorption `K` and scattering `S` are carried separately
  (not just the ratio `K/S`), which is what lets opaque and transparent pigments behave
  differently and makes mixtures desaturate physically.
- **Saunderson correction** for surface (Fresnel) reflection, with per-medium constants.
- **Forward** mixing is a few length-31 vector operations; the **inverse** solver
  enumerates palette subsets (preferring fewer paints) and optimizes volumes to minimize
  ΔE00, returning the top recipes within an interactive time budget.
- **Provenance:** recipes solved from measured data are labelled *Calculated*; a pigment
  whose `K`,`S` the user measured from their own tube is *Measured*. Third-party datasets
  are never, by themselves, promoted to *Measured*.

```dart
// Illustrative — target API shape.
final engine = CustomKmEngine.load();               // measured-pigment engine
final colour = engine.forward({'ultramarine': 0.7, 'titanium_white': 0.3});
final recipes = engine.inverse(target, myPalette, const MixOptions(topK: 3));
for (final r in recipes) {
  print('${r.parts}  ΔE00=${r.deltaE00}  ${r.outOfGamut ? "(nearest, out of gamut)" : r.verdict}');
}
```

## Data sources & attribution

This library stands on published colour-science research and measured datasets. The engine
code is MIT-licensed (see **License**); the pigment data it incorporates keeps its own terms,
summarized here and in [`NOTICE`](NOTICE).

### Engine / methods

- **Spectral.js** — Ronald van Wijnen. MIT License.
  The spectrum→XYZ→sRGB conversion and OKLCh gamut mapping are derived from Spectral.js;
  its two-constant Kubelka–Munk upgrade and the measured-pigment data are this library's
  contribution. <https://github.com/rvanwijnen/spectral.js>
- **LHTSS reflectance reconstruction** — Scott Burns. The RGB→spectrum method Spectral.js
  builds on. <http://scottburns.us/>

### Acrylic pigment data — RIT Artist Paint Spectral Database

Absorption (**K**) and scattering (**S**) spectra for Golden Heavy Body acrylics are derived
from the **RIT Artist Paint Spectral Database** (Okumura 2005; Berns 2022), developed at the
**Munsell Color Science Laboratory, Rochester Institute of Technology**.

This data is included **with the kind permission of Prof. Roy S. Berns (RIT MCSL)**, granted
in 2026 for the use described to him — inclusion in this open-source library and the
accessibility application built on it, with clear attribution. **It is not placed under this
repository's MIT license** and remains the work of RIT / the Munsell Color Science Laboratory.
If you wish to reuse the RIT data in your own work, please seek permission from RIT/MCSL
rather than relying on this grant.

Please cite:

- Okumura, Y. (2005). *Developing a spectral and colorimetric database of artist paint
  materials.* M.S. thesis, Rochester Institute of Technology, Munsell Color Science Laboratory.
- Berns, R. S. (2022). *An Artist Acrylic Paint Spectral, Colorimetric, and Image Dataset.*
  IS&T Archiving Conference.

Methodology and the authoritative dataset description: <https://artistpigments.org/methodology>

### Oil pigment data — MPI multispectral dataset *(planned)*

Oil (Old Holland) optical data is derived from the Max Planck Institute multispectral
oil-and-watercolor paint dataset, used under **CC BY 4.0** with attribution:

> Oil-paint optical data derived from: Azadeh Asadi Shahmirzadi, Vahid Babaei, and
> Hans-Peter Seidel, "A Multispectral Dataset of Oil and Watercolor Paints," IS&T
> Electronic Imaging, Material Appearance, 2020. Licensed under CC BY 4.0
> (<https://creativecommons.org/licenses/by/4.0/>). Changes: spectral reflectances resampled
> to this library's canonical wavelength grid and used to derive two-constant Kubelka–Munk
> K/S coefficients.

## License

- **Code:** MIT — see [`LICENSE`](LICENSE). © 2026 Matt Quirk.
- **Bundled / derived pigment data:** see [`NOTICE`](NOTICE). The RIT acrylic data is used by
  permission (not MIT); the MPI oil data is CC BY 4.0. The MIT license covers this library's
  source code, **not** the third-party data it incorporates.

## Acknowledgements

With gratitude to **Prof. Roy S. Berns** and the RIT Munsell Color Science Laboratory for
the foundational artist-paint spectral research — and for permission to build on it — and to
Ronald van Wijnen (Spectral.js), Scott Burns (LHTSS), and Asadi, Babaei & Seidel (MPI dataset).
