import SwiftUI

// MARK: - Constellation names
// Visibility classification + label rendering for the
// constellation labels (`ConstellationNamesLayer`).
//
// As of the plain-text redesign, constellations are NOT drawn as POI
// badges any more — they're treated like *regions* (the way Apple
// Maps draws town / neighbourhood names), with three zoom tiers:
//
//   • scale < `constellationPlaceholderIn`  → nothing
//   • placeholderIn ≤ scale < textIn        → fixed-width neutral
//                                              capsule placeholder
//                                              (visually-only, non-
//                                              tappable; says "a name
//                                              lives here, zoom for it")
//   • scale ≥ `constellationTextIn`         → plain text label, with
//                                              an inline ♥ prefix +1
//                                              font weight for favourites
//
// This file owns the *geometry* of "does this constellation rise /
// set at the observer's latitude" plus the new draw helper and the
// tunable knobs that shape it.
extension EArtist {

    // MARK: Tier thresholds

    /// Scale below which constellation labels are completely hidden.
    /// At default zoom (~40) the canvas shows lines, stars and the
    /// solar bodies — the constellation names appear as you zoom in.
    var constellationPlaceholderIn: Double { 60 }

    /// Scale at which the neutral capsule placeholder resolves into
    /// the actual constellation name. Below this and above
    /// `constellationPlaceholderIn`, only the placeholder is shown.
    var constellationTextIn: Double { 240 }

    // MARK: Placeholder

    /// Placeholder pill dimensions interpolated across the
    /// placeholder zoom range — extra-tiny at `constellationPlaceholderIn`
    /// (just visual guidance: "a name will live here when you
    /// keep zooming"), full-size at `constellationTextIn` (a hint
    /// at the text bounds about to appear). Equal for every
    /// constellation so the placeholder tier reads as a calm grid
    /// of equal weights rather than telegraphing word lengths.
    var constellationPlaceholderMinSize: CGSize { CGSize(width: 8,  height: 3)  }
    var constellationPlaceholderMaxSize: CGSize { CGSize(width: 36, height: 10) }

    /// Placeholder fill — a system tertiary fill so it adapts to
    /// light / dark mode and reads as a *skeleton* rather than an
    /// actual button.
    var constellationPlaceholderFill: Color { Color(.tertiarySystemFill) }

    // MARK: Text

    /// Base point size for the plain-text label. Matches the
    /// "town" label idiom in Apple Maps — small, legible, calm.
    var constellationLabelFontSize: CGFloat { 12 }

    /// Same typographic colour for every constellation — myth tint
    /// lives in the detail sheet (and, on canvas, in the figure
    /// lines for favourites). The only typographic difference
    /// between a favourite and a non-favourite is `+1 font weight`.
    func constellationLabelFont(isFavourite: Bool) -> Font {
        .system(size:   constellationLabelFontSize,
                weight: isFavourite ? .semibold : .regular,
                design: .rounded)
    }

    // MARK: Visibility helpers

    /// Margin (degrees of declination) for the horizon visibility
    /// test. Constellations span tens of degrees, so a centroid
    /// just below 90° from the observer can still have figure-stars
    /// rising — the margin keeps those visible.
    var constellationVisibilityMargin: Double { 25 }

    /// `true` when any part of a constellation near `decDegrees` rises
    /// above the horizon for an observer at `observerLatitude`. A point
    /// at declination δ culminates at altitude 90° − |φ − δ|, so it is
    /// below the horizon for the whole sidereal day once |φ − δ| ≥ 90°.
    func constellationEverVisible(decDegrees: Double, observerLatitude: Double) -> Bool {
        abs(observerLatitude - decDegrees) < 90 + constellationVisibilityMargin
    }

    /// `true` when the constellation's centroid never sets at the
    /// observer's latitude — i.e. the centroid sits within |φ| of
    /// the observer's celestial pole. Same hemisphere as observer
    /// (north + north, south + south); a southern observer's
    /// circumpolar constellations live at negative dec.
    func constellationCircumpolar(decDegrees: Double, observerLatitude: Double) -> Bool {
        if observerLatitude >= 0 {
            return decDegrees >= 90 - observerLatitude
        } else {
            return decDegrees <= -(90 + observerLatitude)
        }
    }

    /// Resolve a constellation's POI kind:
    ///   • `.foreverInvisible` when the centroid never rises at
    ///     the observer's latitude. With the plain-text redesign
    ///     `ConstellationNamesLayer` hides these entirely — they no
    ///     longer render as recessive grey ghosts.
    ///   • `.myth(_)` otherwise — used by `ConstellationLinesLayer`
    ///     to colour-code the favourite stick-figure lines.
    func constellationKind(_ cons: EConstellation,
                           decDegrees: Double,
                           observerLatitude: Double) -> POIConstellationKind {
        if !constellationEverVisible(decDegrees:       decDegrees,
                                     observerLatitude: observerLatitude) {
            return .foreverInvisible
        }
        return .myth(constellationMyth(of: cons))
    }

    /// Title-cased constellation name as it appears on the label.
    func constellationLabelText(for cons: EConstellation) -> String {
        cons.fullName
    }

    // MARK: Draw

    /// Draw the constellation label at the projected centroid `sc`.
    /// Dispatches on `dc.renderedScale` through the three tiers:
    /// nothing, placeholder pill, plain text. Returns the on-screen
    /// rect the text occupies when the *text* tier is reached, so
    /// the caller can publish a hit-target — placeholders and the
    /// nothing-tier return `nil` (they're visual-only / absent).
    ///
    /// `heartColor` is only sampled when `isFavourite` is true; the
    /// caller picks the myth-gradient top so the inline heart
    /// echoes the colour of the favourited constellation's
    /// stick-figure lines.
    func drawConstellationLabel(at sc: CGPoint,
                                fullName: String,
                                isFavourite: Bool,
                                heartColor: Color,
                                in dc: inout EGraphicContext) -> CGRect? {
        let scale = dc.renderedScale

        // Tier 0 — nothing.
        guard scale >= constellationPlaceholderIn else { return nil }

        // Tier 1 — capsule placeholder. Lerps from a tiny "visual
        // guidance" pill at the bottom of the placeholder range up
        // to roughly the text bounds at the top, so the morph into
        // tier 2 doesn't feel like a sudden expansion.
        guard scale >= constellationTextIn else {
            let t        = CGFloat((scale - constellationPlaceholderIn)
                                 / (constellationTextIn - constellationPlaceholderIn))
            let clampedT = max(0, min(1, t))
            let minSz    = constellationPlaceholderMinSize
            let maxSz    = constellationPlaceholderMaxSize
            let w        = minSz.width  + (maxSz.width  - minSz.width)  * clampedT
            let h        = minSz.height + (maxSz.height - minSz.height) * clampedT
            let rect     = CGRect(x: sc.x - w / 2, y: sc.y - h / 2, width: w, height: h)
            var shadowed = dc.ctx
            shadowed.addFilter(poiShadow)
            shadowed.fill(Capsule(style: .continuous).path(in: rect),
                          with: .color(constellationPlaceholderFill))
            return nil    // placeholders aren't tappable
        }

        // Tier 2 — plain text (with an inline ♥ prefix for
        // favourites, +1 font weight). Two-Text concatenation lets
        // the heart take its own colour while the name stays
        // primary; one font modifier wraps the whole pill.
        var shadowed = dc.ctx
        shadowed.addFilter(poiShadow)

        let label: Text
        if isFavourite {
            label = Text(Image(systemName: "heart.fill"))
                        .foregroundStyle(heartColor)
                  + Text(" \(fullName)")
                        .foregroundStyle(.primary)
        } else {
            label = Text(fullName)
                        .foregroundStyle(.primary)
        }
        shadowed.draw(
            label.font(constellationLabelFont(isFavourite: isFavourite)),
            at:     sc,
            anchor: .center
        )

        // Approximate text bounds for hit-targeting. Measuring
        // SwiftUI Text inside a Canvas closure is awkward and
        // overkill for tap-target sizing — a per-character estimate
        // (~48% of point size on the .rounded font, plus a fixed
        // ~13pt for the heart glyph when present) lands within a
        // pixel or two of reality, which is well inside the padding
        // the caller adds.
        let charW: CGFloat = constellationLabelFontSize * 0.48
        let heartW: CGFloat = isFavourite ? 13 : 0
        let textW: CGFloat  = CGFloat(fullName.count) * charW + heartW
        let textH: CGFloat  = constellationLabelFontSize * 1.2
        return CGRect(x: sc.x - textW / 2,
                      y: sc.y - textH / 2,
                      width:  textW,
                      height: textH)
    }
}
