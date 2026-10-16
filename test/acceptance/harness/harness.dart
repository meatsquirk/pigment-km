/// The pigment_km acceptance harness (ITEST-1).
///
/// One import for the per-AC acceptance tests (ITEST-2/3/4): it re-exports the
/// [pendingACs] gate and the fixtures, and provides the Given/When/Then builder
/// vocabulary the scenarios share. Everything here goes through the package's
/// PUBLIC surface only (`package:pigment_km/pigment_km.dart`) — no test reaches
/// into `lib/src`, so the suite exercises exactly what a consumer would. The
/// AC-test phases extend this vocabulary with the builders their scenarios need.
library;

import 'package:pigment_km/pigment_km.dart';

export 'fixtures.dart';
export 'pending.dart';

/// GIVEN the measured-pigment, two-constant Kubelka–Munk engine under test.
MixingEngine customEngine() => const CustomKmEngine();

/// GIVEN the single-constant spectral baseline engine — the A/B counterpart
/// that implements the same [MixingEngine] surface (AC-25).
MixingEngine baselineEngine() => const SpectralBaselineEngine();

/// GIVEN the loaded acrylic pigment table (the synthetic table until G-3).
PigmentTable givenAcrylicTable() => PigmentTable.load(Medium.acrylic);

/// GIVEN the loaded oil pigment table (the synthetic table until G-4).
PigmentTable givenOilTable() => PigmentTable.load(Medium.oil);
