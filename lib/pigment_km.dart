/// pigment_km — measured-pigment, two-constant Kubelka–Munk colour mixing.
///
/// This is the package entry point. The public surface (the `MixingEngine`
/// interface, the colour and pigment value types, the canonical spectral grid)
/// is exported here as the component-shell phases land it. During the scaffold
/// phase the package carries only its version marker so the toolchain, the test
/// runner and the coverage gate have real, executable code to exercise.
library;

/// The package version string, kept in sync with `pubspec.yaml`.
///
/// Exposed as a function (not a `const`) so the scaffold has an executable line
/// for the coverage gate to prove itself against before any product code exists.
String packageVersion() => '0.0.1';
