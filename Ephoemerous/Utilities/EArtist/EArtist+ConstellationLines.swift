import SwiftUI

// MARK: - Constellation lines
// Thin, low-contrast strokes between the figure-stars of each
// constellation. Each segment is *inset* on both ends by a per-star
// breathing gap so the line never touches the star dot.
extension EArtist {

    var constellationLineColor : Color  { palette.constellationLine }
    var constellationLineWidth : Double { 1.0 }

    /// Stroke width for a favourited constellation's stick-figure
    /// lines. Slightly bumped over the normal width so the solid
    /// (un-dotted) emphasis reads cleanly.
    var constellationFavouriteLineWidth : Double { 1.0 }

    /// Hand-drawn "squiggle" flare for the SELECTED constellation: each
    /// segment becomes a gentle sine wave instead of a straight line.
    /// `Amplitude` is the perpendicular wiggle in points; `Wavelength` the
    /// screen distance per full wave (so denser figures wiggle more times).
    var constellationSquiggleAmplitude  : Double { 0.0 }
    var constellationSquiggleWavelength : Double { 16 }

    /// Centre-to-centre spacing between dots along a stick-figure
    /// segment. Tunable — increase for sparser, decrease for denser.
    var constellationLineDotPitch : Double { 2.4 }

    /// Extra screen-space gap added to each end of a segment, *on top*
    /// of the projected star radius. Keeps a visible halo of bare canvas
    /// around every star regardless of zoom.
    var constellationLineGapPad    : Double { 2.7 }

    /// Magnitude cutoff above which we don't bother drawing a segment.
    /// Set generously — figure-stars are almost always Vmag < 4 anyway.
    var constellationLineMagCutoff : Double { 6.5 }

    // The stroking itself (drawConstellationSegment / …Favourite /
    // …Squiggle) now lives on `ConstellationLinesLayer` — these constants
    // are its only remaining tie here, and carry no `EGraphicContext`.
}
