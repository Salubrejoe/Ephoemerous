import SwiftUI
import simd
import LoreKit

// MARK: - SkyLabCartographyLabels
// The curved cartographic labels — EASTERN / WESTERN HORIZON riding the
// alt = 0 rim, and the four colure names (VERNAL EQUINOX … WINTER
// SOLSTICE) riding their constant-RA meridians. Curved text is genuine
// Canvas work (each glyph projected + rotated along the curve), so this
// stays a Canvas — but `.equatable()` on the frozen camera means it only
// redraws on a settle / date / origin move, never per gesture frame; the
// shared parent transform scales the raster meanwhile.
//
// Strings reuse the already-localised catalogue keys.
struct CartographyLabels: View, Equatable {

    let camera:   SkyCamera
    let latitude: Angle   // observer latitude → sun rise/set azimuths
    let date:     Date    // → sun declination today

    // Camera already folds in observer (viewpoint) + time (sidereal); add
    // latitude+date so the twilight roster redraws when they move.
    static func == (l: Self, r: Self) -> Bool {
        l.camera == r.camera && l.latitude == r.latitude && l.date == r.date
    }

    private struct Colure { let ra: Angle; let centreDec: Double; let text: String }
    private struct Band   { let altitude: Angle; let rising: String; let setting: String }

    var body: some View {
        Canvas { ctx, _ in
            let artist = EArtist.shared
            let zenith = camera.screen(.zero)
            let horizonFont   = Font.caption2.weight(.light)
//            let horizonFont   = Font.system(size: 10, weight: .regular)
            let twilightFont  = Font.caption2.weight(.ultraLight)
//            let twilightFont  = Font.system(size: 6,  weight: .regular)
            let merdianF      = Font.caption2.weight(.ultraLight)
//            let merdianF      = Font.system(size: 6,  weight: .regular)
            // Match each label's weight to its line: horizon labels to the
            // bolder horizon ring, colure labels to the faint grid meridians.
            let horizonColor  = artist.gridColor
//            let horizonColor  = Color.secondary.opacity(0.7)
            let meridianColor = artist.gridColor

            // Horizon rim (alt = 0). t: 0 = N, 0.25 = W, 0.5 = S, 0.75 = E.
            drawCurved(String(localized: "EASTERN HORIZON"), centre: 0.75, probe: 0.01,
                       point: horizonPoint, zenith: zenith, color: horizonColor, font: horizonFont, ctx)
            drawCurved(String(localized: "WESTERN HORIZON"), centre: 0.25, probe: 0.01,
                       point: horizonPoint, zenith: zenith, color: horizonColor, font: horizonFont, ctx)

            // Colures — constant-RA meridians through the equinox/solstice points.
            let eps = AstroConstants.obliquity.radians
            let colures: [Colure] = [
                .init(ra: Angle(hours: 0),  centreDec:  0,   text: String(localized: "VERNAL EQUINOX")),
                .init(ra: Angle(hours: 6),  centreDec:  eps, text: String(localized: "SUMMER SOLSTICE")),
                .init(ra: Angle(hours: 12), centreDec:  0,   text: String(localized: "AUTUMNAL EQUINOX")),
                .init(ra: Angle(hours: 18), centreDec: -eps, text: String(localized: "WINTER SOLSTICE")),
            ]
            for c in colures {
                drawCurved(c.text, centre: c.centreDec, probe: 0.0017,   // 0.5° in radians
                           point: { meridianPoint(ra: c.ra, dec: $0) },
                           zenith: zenith, color: meridianColor, font: merdianF, ctx)
            }

            // Twilight roster — each band rides its own almucantar ring at
            // the sun's RISE azimuth (east) and the mirror SET azimuth
            // (west), so they sit where the sun actually crosses that
            // altitude today (and clear of EASTERN/WESTERN HORIZON).
            let twilightColor = artist.gridColor
            let phi = latitude.radians
            let dec = sunDeclination
            let bands: [Band] = [
//                .init(altitude: .degrees(  0), rising: String(localized: "sunrise"),
//                                               setting: String(localized: "sunset")),
                .init(altitude: .degrees( -6), rising: String(localized: "civil"),
                                               setting: String(localized: "civil")),
                .init(altitude: .degrees(-12), rising: String(localized: "nautical"),
                                               setting: String(localized: "nautical")),
                .init(altitude: .degrees(-18), rising: String(localized: "astronomical"),
                                               setting: String(localized: "astronomical")),
            ]
            for band in bands {
                guard let riseAz = sunRiseAzimuth(altitude: band.altitude.radians,
                                                  dec: dec, lat: phi) else { continue }
                let point: (Double) -> CGPoint? = { t in
                    camera.screen(rotatedEquatorial:
                        camera.viewpoint.skyPoint(altitude: band.altitude, at: t))
                }
                drawCurved(band.rising,  centre: azimuthToT(riseAz),
                           probe: 0.01, point: point, zenith: zenith,
                           color: twilightColor, font: twilightFont, ctx)
                drawCurved(band.setting, centre: azimuthToT(2 * .pi - riseAz),
                           probe: 0.01, point: point, zenith: zenith,
                           color: twilightColor, font: twilightFont, ctx)
            }
        }
    }

    // MARK: Sun geometry (twilight placement)

    private var sunDeclination: Double {
        let lambda = ESunPosition.eclipticLongitude(for: date)
        return ESunPosition.equatorialCoords(lambda: lambda).dec.radians
    }

    /// Eastern (rising) azimuth where the sun reaches altitude `h`, or
    /// `nil` on a polar day/night (the band never crosses). Mirror set
    /// side is `2π − A`.
    private func sunRiseAzimuth(altitude h: Double, dec: Double, lat phi: Double) -> Double? {
        let cosH = (sin(h) - sin(phi) * sin(dec)) / (cos(phi) * cos(dec))
        guard cosH >= -1, cosH <= 1 else { return nil }
        let cosA = (sin(dec) - sin(phi) * sin(h)) / (cos(phi) * cos(h))
        return acos(max(-1, min(1, cosA)))
    }

    /// Azimuth (CW from north) → horizon circle parameter t, matching
    /// `skyPoint`'s basis (e1 north, e2 west): t·2π = −azimuth.
    private func azimuthToT(_ azimuth: Double) -> Double {
        let t = -azimuth / (2 * .pi)
        return t - floor(t)
    }

    // MARK: Curve points

    private func horizonPoint(_ t: Double) -> CGPoint? {
        camera.screen(rotatedEquatorial: camera.viewpoint.skyPoint(altitude: .degrees(0), at: t))
    }

    private func meridianPoint(ra: Angle, dec: Double) -> CGPoint? {
        camera.screen(equatorial: EPrecession.equatorialVector(ra: ra, dec: .radians(dec)))
    }

    // MARK: Per-glyph placement

    /// Step the characters along `point(param)`, rotating each to the
    /// local tangent and flipping the whole word (once, at its centre) so
    /// its "up" faces the zenith — the same readability rule the
    /// production labels use. `probe` is a small param delta for the
    /// initial screen-spacing measurement.
    private func drawCurved(_ text: String,
                            centre: Double,
                            probe: Double,
                            point: (Double) -> CGPoint?,
                            zenith: CGPoint,
                            color: Color,
                            font: Font,
                            _ ctx: GraphicsContext) {
        let chars = Array(text)
        let n = chars.count
        guard n > 1 else { return }

        // Param step for ~`spacing` screen-pt between glyphs, measured
        // locally (a meridian's projected scale varies along its length).
        guard let a = point(centre - probe), let b = point(centre + probe) else { return }
        let perParam = hypot(b.x - a.x, b.y - a.y) / (2 * probe)
        guard perParam > 0.0001 else { return }
        let spacing: CGFloat = 9
        let delta = Double(spacing) / Double(perParam)
        let half  = delta * Double(n - 1) / 2

        // One flip decision for the whole word, at its centre.
        guard let pc = point(centre),
              let pp = point(centre - delta),
              let pn = point(centre + delta) else { return }
        let tangent = atan2(pn.y - pp.y, pn.x - pp.x)
        let upX = -sin(tangent), upY = cos(tangent)
        let inX = zenith.x - pc.x, inY = zenith.y - pc.y
        let inMag = hypot(inX, inY)
        let dot   = upX * inX + upY * inY
        // Normally flip so the word's "up" faces the projection centre (dome
        // readability). But when the line runs (near-)radially THROUGH the
        // centre — every colure meridian in NorthOUT — "up" is perpendicular
        // to "toward-centre", so this dot product sits on zero and the whole
        // word chatters end-for-end on any sub-pixel change. In that
        // degenerate zone fall back to a stable screen rule: read
        // left-to-right (baseline advancing rightward).
        let flip: Bool
        if inMag > 0.5, abs(dot) > inMag * 0.2 {
            flip = dot < 0
        } else {
            flip = cos(tangent) < 0
        }
        let ordered = flip ? Array(chars.reversed()) : chars

        // Push the whole word to ONE side of the line — along each glyph's
        // local +Y (perpendicular to the tangent), which after the flip
        // always faces the zenith — so the text floats beside its line
        // instead of sitting on it (and crossing the other labels at the
        // intersections).
        let sideInset: CGFloat = 6

        for (i, ch) in ordered.enumerated() {
            let p = centre - half + delta * Double(i)
            guard let here = point(p),
                  let prev = point(p - delta),
                  let next = point(p + delta) else { continue }
            var rotation = atan2(next.y - prev.y, next.x - prev.x)
            if flip { rotation += .pi }

            let pos = CGPoint(x: here.x - CGFloat(sin(rotation)) * sideInset,
                              y: here.y + CGFloat(cos(rotation)) * sideInset)
            var g = ctx
            g.translateBy(x: pos.x, y: pos.y)
            g.rotate(by: .radians(rotation))
            g.draw(Text(String(ch)).font(font).foregroundStyle(color),
                   at: .zero, anchor: .center)
        }
    }
}
