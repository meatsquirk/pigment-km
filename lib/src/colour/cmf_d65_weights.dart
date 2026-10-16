/// Precomputed `CMF·D65` weight vectors on the canonical 400–700 nm @ 10 nm grid
/// (design §2, §3.5; AC-1 backend).
///
/// Each entry `i` is the CIE 1931 2° colour-matching function value at the i-th
/// canonical wavelength multiplied by the relative spectral power of CIE
/// standard illuminant D65 there: `xBarD65[i] = x̄(λ_i)·S_D65(λ_i)`, and likewise
/// for ȳ and z̄. Folding the illuminant and observer into one weight vector per
/// channel turns spectrum→XYZ into three length-31 dot products (the Spectral.js
/// backend approach ported to the canonical grid).
///
/// Tristimulus for a reflectance spectrum `R` is
/// `X = Σ R·xBarD65 / k`, `Y = Σ R·yBarD65 / k`, `Z = Σ R·zBarD65 / k`
/// with `k = yBarD65Sum = Σ yBarD65`, so a perfect diffuser (`R ≡ 1`) yields the
/// D65 white point with `Y = 1`. Over this 400–700 nm range that white point is
/// `(0.9494, 1.0, 1.0871)`, within ΔE00 ≈ 0.30 of the full-range D65 white
/// `(0.95047, 1.0, 1.08883)` — the energy outside the range is negligible.
///
/// **Data provenance:** CIE 1931 2° standard observer colour-matching functions
/// and the CIE standard illuminant D65 relative spectral power distribution,
/// both at 10 nm from 400–700 nm (standard CIE colorimetric reference data,
/// as tabulated by the `colour-science` project). The products below were
/// computed from those two tables.
library;

/// `x̄(λ)·S_D65(λ)` on the 31-bin canonical grid.
const List<double> xBarD65 = <double>[
  1.184222619,
  3.9805558600000004,
  12.555365283999999,
  24.609104969999997,
  36.522382199999996,
  39.338089599999996,
  34.2597296,
  22.43924496,
  11.08687572,
  3.4830401099999997,
  0.5358345999999999,
  1.0025586,
  6.6300633000000015,
  17.822529499999998,
  30.319212,
  45.0987282954,
  59.45,
  73.41629381999999,
  87.77054439999999,
  91.01803127999999,
  95.60458564000001,
  89.83205766,
  74.93414544513,
  53.50459664,
  37.48887168,
  22.687597799999995,
  13.22738754,
  7.19107972,
  3.6613520339999996,
  1.58267351,
  0.813419224356,
];

/// `ȳ(λ)·S_D65(λ)` on the 31-bin canonical grid (the luminance channel).
const List<double> yBarD65 = <double>[
  0.032770940400000004,
  0.11069806,
  0.3737272,
  1.0055146799999999,
  2.411895,
  4.446304,
  7.06872,
  10.450053780000001,
  16.11561546,
  22.634864220000004,
  35.321342,
  54.224406,
  74.40090000000001,
  92.827918,
  99.60237,
  103.5205781046,
  99.5,
  91.7101584,
  83.33556,
  67.1349992,
  56.79391220000001,
  45.068347300000006,
  33.4132047,
  22.071479,
  14.647359999999999,
  8.562867599999999,
  4.8930906,
  2.6328896,
  1.3308314,
  0.572411873,
  0.29374052819999996,
];

/// `z̄(λ)·S_D65(λ)` on the 31-bin canonical grid.
const List<double> zBarD65 = <double>[
  5.614920792549,
  18.9741964,
  60.31957007999999,
  120.10699487999999,
  183.2054469,
  207.35104688,
  196.6517904,
  147.89961804,
  94.23961444230001,
  50.616700980000005,
  29.744288,
  17.054276400000003,
  8.1998164521,
  4.54016824,
  2.1194215,
  0.910402395954,
  0.38999999999999996,
  0.20230181999999997,
  0.15805029578799998,
  0.09755416,
  0.07200496,
  0.030463694000000003,
  0.016662753000000002,
  0.0041644291671140005,
  0.0016739840000000003,
  0.0,
  0.0,
  0.0,
  0.0,
  0.0,
  0.0,
];

/// The luminance-normalization constant `k = Σ yBarD65` (design §2). Dividing
/// each tristimulus sum by this makes a perfect diffuser's `Y` exactly 1.
const double yBarD65Sum = 1056.5085298462;
