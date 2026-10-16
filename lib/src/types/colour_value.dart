/// An sRGB colour, channels in the range 0..1 (design §10; the library's own
/// colour type, not Flutter's — see CORE module interface reconciliation, D-3).
typedef Srgb = ({double r, double g, double b});

/// A CIE 1931 XYZ tristimulus value.
typedef Xyz = ({double x, double y, double z});

/// An OKLCh colour (lightness, chroma, hue°), used for gamut mapping (design §2).
typedef Oklch = ({double l, double c, double h});

/// A predicted colour carried in three spaces at once: [srgb] for display,
/// [xyz] for colour-difference maths, and [oklch] for gamut mapping.
///
/// The three are meant to describe the *same* colour; nothing in this value type
/// enforces that — the colour backend (COLOR phases) produces consistent triples.
class ColourValue {
  const ColourValue({
    required this.srgb,
    required this.xyz,
    required this.oklch,
  });

  final Srgb srgb;
  final Xyz xyz;
  final Oklch oklch;

  @override
  bool operator ==(Object other) =>
      other is ColourValue &&
      other.srgb == srgb &&
      other.xyz == xyz &&
      other.oklch == oklch;

  @override
  int get hashCode => Object.hash(srgb, xyz, oklch);
}
