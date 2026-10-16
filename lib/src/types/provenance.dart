/// The honesty tier of a pigment's K,S data or a solved recipe (SI D9).
///
/// - [measured]: measured directly from a physical swatch/tube (the user's own).
/// - [calculated]: derived from measured pigment data through the model.
/// - [estimated]: inferred without measured backing (lowest confidence).
/// - [confirmed]: a calculated result the user physically checked and accepted.
///
/// Ordered weakest-source to strongest-confirmation is *not* implied; these are
/// categorical tiers, not a numeric scale.
enum Provenance { measured, calculated, estimated, confirmed }
