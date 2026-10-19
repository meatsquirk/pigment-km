/// Precomputed `CMF·D65` weight vectors on the canonical 400–700 nm @ 10 nm grid
/// (design §2, §3.5; AC-1 backend).
///
/// Each entry `i` is the CIE 1964 10° colour-matching function value at the i-th
/// canonical wavelength multiplied by the relative spectral power of CIE
/// standard illuminant D65 there: `xBarD65[i] = x̄₁₀(λ_i)·S_D65(λ_i)`, and
/// likewise for ȳ₁₀ and z̄₁₀. Folding the illuminant and observer into one weight
/// vector per channel turns spectrum→XYZ into three length-31 dot products (the
/// Spectral.js backend approach ported to the canonical grid).
///
/// Tristimulus for a reflectance spectrum `R` is
/// `X = Σ R·xBarD65 / k`, `Y = Σ R·yBarD65 / k`, `Z = Σ R·zBarD65 / k`
/// with `k = yBarD65Sum = Σ yBarD65`, so a perfect diffuser (`R ≡ 1`) yields the
/// D65 white point with `Y = 1`. Over this 400–700 nm range that white point is
/// `(0.9478, 1.0, 1.0735)`, within ΔE00 ≈ 0.08 of the full-range D65/10° white
/// `(0.94811, 1.0, 1.07304)` — the energy outside the range is negligible.
///
/// **Observer (G-9 / D-14):** the colour pipeline uses the **CIE 1964 10°**
/// standard observer, not the 2°. The Golden/RIT acrylic dataset publishes its
/// colours as D65/**10°** L\*a\*b\*; matching that observer is what lets AC-7's
/// round-trip hit ΔE00 ≤ 0.5 (under 2° it could not — the mismatch is
/// chroma-correlated and no k1,k2/grid choice fixes an observer difference). The
/// Lab reference white used for ΔE00 (`inverse.dart`, and the acceptance
/// yardstick) moves to the 10° white in the same change. The sRGB display matrix
/// + gamma stay the standard sRGB ones (a display encoding, not a colorimetric
/// observer).
///
/// **Data provenance:** CIE 1964 10° standard observer colour-matching functions
/// and the CIE standard illuminant D65 relative spectral power distribution,
/// both at 10 nm from 400–700 nm (standard CIE colorimetric reference data,
/// as tabulated by the `colour-science` project — the same authoritative source
/// as the superseded 2° weights). The products below were computed from those
/// two tables (the method was validated by reproducing the prior 2° vectors
/// exactly before re-basing to 10°).
library;

/// `x̄₁₀(λ)·S_D65(λ)` on the 31-bin canonical grid.
const List<double> xBarD65 = <double>[
  1.5814213125300005,
  7.752157695999996,
  19.106055645599998,
  27.27709948169999,
  40.24026591,
  43.375099615999964,
  35.61138667599996,
  22.468879097999988,
  9.332612960999997,
  1.7596914919999984,
  0.4172948639999999,
  4.038801930000002,
  12.338917709999999,
  25.467479299000008,
  39.336880660000006,
  55.12627599599998,
  70.52240000000005,
  84.644526501,
  97.14435808000003,
  99.19661731199997,
  101.16606873799995,
  92.33008056800007,
  75.09613371390007,
  53.92661997620002,
  36.12181264639999,
  21.47351121719999,
  12.23818109279999,
  6.685943394679997,
  3.1979721973599986,
  1.3903333596900003,
  0.6857917576080006,
];

/// `ȳ₁₀(λ)·S_D65(λ)` on the 31-bin canonical grid (the luminance channel).
const List<double> yBarD65 = <double>[
  0.1658739215600001,
  0.8010514159999991,
  1.9985996338000003,
  3.3525246347999995,
  6.509704605000001,
  10.467067648000002,
  15.103616211999995,
  21.271108590000008,
  29.396797647000014,
  36.90140086300003,
  50.38780805799999,
  65.40789328199993,
  79.82451603000004,
  94.25059737899996,
  100.4363571400001,
  103.18876500599998,
  99.73399999999998,
  92.05233747840002,
  83.23344999200002,
  68.94462886800002,
  59.25477171420002,
  47.3050096333,
  34.909081425900006,
  23.6117350798,
  15.051459737599988,
  8.613524564399997,
  4.8354163026000005,
  2.6164669511199965,
  1.24511802942,
  0.5402564094399999,
  0.26622401543400004,
];

/// `z̄₁₀(λ)·S_D65(λ)` on the 31-bin canonical grid.
const List<double> zBarD65 = <double>[
  7.117823428409994,
  35.621537876000026,
  90.8663496356,
  134.65921940400008,
  206.2988172000001,
  233.40755839999997,
  205.62553044000003,
  151.33625915999997,
  89.50704637499994,
  45.18420299400004,
  23.894067707999987,
  12.078567288000006,
  6.3616961100000005,
  3.279237739000001,
  1.427842780000002,
  0.4149354480000002,
  0.0,
  0.0,
  0.0,
  0.0,
  0.0,
  0.0,
  0.0,
  0.0,
  0.0,
  0.0,
  0.0,
  0.0,
  0.0,
  0.0,
  0.0,
];

/// The luminance-normalization constant `k = Σ yBarD65` (design §2). Dividing
/// each tristimulus sum by this makes a perfect diffuser's `Y` exactly 1.
const double yBarD65Sum = 1161.6771622677738;
