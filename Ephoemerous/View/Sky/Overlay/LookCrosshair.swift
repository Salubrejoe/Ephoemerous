import SwiftUI
import UIKit
import LoreKit

// MARK: - LookCrosshair
// LOOK mode's sight (see `Artist+Aim`): a ring FIXED at the screen's
// centre while the sky moves under it with the hand — the window model,
// where the phone's back is the only thing that points. Anything you could
// tap — a named star, a planet, the Moon — that slides inside LOCKS: the
// ring takes the accent ("live / engaged") with a selection tick, grows a
// touch and OPENS — the name written into the top of the circle, the
// distance (when we know it) into the bottom, each sitting in the gap its
// own letters leave. A bezel inscription rather than a caption under a ring.
//
// Fades in with the window; locks only once the window is nearly open, so
// the sweep through the transition doesn't tick at every star it passes.
// Before that, while the overhead hold is ARMING the window, the ring
// draws itself round the centre (`LookArmingRing`) — the hold you can see.
struct LookCrosshair: View {

    let camera: SkyCamera
    let date:   Date
    /// The screen's centre, in this (oversized) canvas's coordinates.
    let centre: CGPoint
    /// How open the window is, 0…1.
    let blend:  Double
    @Environment(AppState.self) private var app
    /// Ring and letters grow with the Text Size (see `Artist+TypeScale`).
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if app.isArmingLook {
            LookArmingRing(duration: app.lookArmDuration)
                .position(centre)
                .allowsHitTesting(false)
        }
        if blend > 0.01 {
            let a      = Artist.shared
            let type   = a.typeScale(dynamicTypeSize)
            let locked = blend >= a.crosshairLockBlend ? lock() : nil
            let font   = UIFont.systemFont(ofSize: a.labelFont(.caption2, design: .default, size: dynamicTypeSize).pointSize,
                                           weight: .semibold)
            let ring   = Inscription(name:     locked?.displayName,
                                     distance: locked?.distanceLabel(at: date),
                                     font:     font,
                                     tracking: a.crosshairTracking * type,
                                     radius:   (locked == nil ? a.crosshairRadius : a.crosshairLockedRadius) * type)
            let ink    = locked == nil ? Color.primary.opacity(a.crosshairRestOpacity) : Color.accentColor

            ZStack {
                GappedRing(radius:    ring.radius,
                           topGap:    ring.nameGap,
                           bottomGap: ring.distanceGap)
                    .stroke(ink, style: StrokeStyle(lineWidth: a.crosshairLineWidth, lineCap: .round))

                if let name = ring.name {
                    ArcText(text: name, font: font, tracking: ring.tracking,
                            radius: ring.radius, placement: .top)
                        .foregroundStyle(Color.accentColor)
                        .id(name)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                if let distance = ring.distance {
                    ArcText(text: distance, font: font, tracking: ring.tracking,
                            radius: ring.radius, placement: .bottom)
                        .foregroundStyle(Color.accentColor.opacity(a.crosshairDistanceOpacity))
                        .id(distance)
                        .transition(.opacity)
                }
            }
            // Sized to the ring plus room for the letters — not the whole
            // canvas, which a bare Shape would claim (and shadow).
            .frame(width: (ring.radius + 16) * 2, height: (ring.radius + 16) * 2)
            .shadow(color: a.canvasBackground, radius: 2)
            // The ring opens from the top, the letters appearing in the gap.
            .animation(.snappy(duration: 0.35), value: locked?.id)
            .position(centre)
            .opacity(blend)
            .sensoryFeedback(.selection, trigger: locked?.id) { _, new in new != nil }
            .allowsHitTesting(false)
        }
    }

    // MARK: Lock

    /// The tappable object nearest the centre, if it sits inside the ring.
    /// Compared on SCREEN, so the ring is the lock radius at any zoom.
    /// Candidates are what the sky labels: the Sun, the Moon, planets,
    /// spacecraft, favourites and named stars.
    private func lock() -> SkyObject? {
        let radius = Artist.shared.crosshairRadius * Artist.shared.typeScale(dynamicTypeSize)
        var best: (object: SkyObject, distance: CGFloat)?

        func consider(_ object: SkyObject, at p: CGPoint?) {
            guard let p else { return }
            let d = hypot(p.x - centre.x, p.y - centre.y)
            guard d <= radius, d < (best?.distance ?? .infinity) else { return }
            best = (object, d)
        }

        for body in [SkyObject.sun, .moon] + Spacecraft.allCases.map({ .spacecraft($0) }) {
            consider(body, at: SkyLabObjects.screen(body, camera: camera, date: date))
        }
        // One ephemeris pass for every planet, not one per planet.
        for (planet, vec, _, _) in PlanetPosition.allVectors(for: date, siderealOffset: camera.sidereal) {
            consider(.planet(planet), at: camera.screen(rotatedEquatorial: vec))
        }
        for star in app.favouriteStars + SkyFrame.properNamedStars {
            consider(.star(star), at: camera.screen(equatorial: star.equatorialVector))
        }
        return best?.object
    }
}

// MARK: - Inscription
// The locked ring's layout, worked out once: the letters' widths set how
// wide each gap opens, and a name too long for `crosshairMaxArcDeg` grows
// the ring until it fits — Zubenelgenubi gets a bigger bezel, not a
// smaller font.
private struct Inscription {
    let name:        String?
    let distance:    String?
    let tracking:    CGFloat
    let radius:      CGFloat
    /// Gap angles (radians) the two inscriptions cut into the ring.
    let nameGap:     Double
    let distanceGap: Double

    init(name: String?, distance: String?, font: UIFont, tracking: CGFloat, radius base: CGFloat) {
        let a          = Artist.shared
        let name       = name?.uppercased()
        let distance   = distance?.uppercased()
        let nameW      = name.map     { ArcText.width(of: $0, font: font, tracking: tracking) } ?? 0
        let distanceW  = distance.map { ArcText.width(of: $0, font: font, tracking: tracking) } ?? 0
        let pad        = a.crosshairArcPadding * 2
        let maxArc     = a.crosshairMaxArcDeg * .pi / 180
        let radius     = max(base, (max(nameW, distanceW) + pad) / CGFloat(maxArc))

        self.name        = name
        self.distance    = distance
        self.tracking    = tracking
        self.radius      = radius
        self.nameGap     = name     == nil ? 0 : Double((nameW     + pad) / radius)
        self.distanceGap = distance == nil ? 0 : Double((distanceW + pad) / radius)
    }
}

// MARK: - GappedRing
// A circle with an opening centred at twelve o'clock and another at six,
// each sized in radians. Gaps and radius animate, so a lock reads as the
// ring growing and parting to make room for its own inscription.
private struct GappedRing: Shape {
    var radius:    CGFloat
    var topGap:    Double
    var bottomGap: Double

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<Double, Double>> {
        get { AnimatablePair(radius, AnimatablePair(topGap, bottomGap)) }
        set { radius = newValue.first; topGap = newValue.second.first; bottomGap = newValue.second.second }
    }

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        // Screen angles: 0 at three o'clock, increasing CLOCKWISE (y down),
        // so twelve is −π/2 and six is +π/2. Right half, then left half.
        let top = -Double.pi / 2, bottom = Double.pi / 2
        arc(&path, c, from: top + topGap / 2,          to: bottom - bottomGap / 2)
        arc(&path, c, from: bottom + bottomGap / 2,    to: top + 2 * .pi - topGap / 2)
        return path
    }

    private func arc(_ path: inout Path, _ c: CGPoint, from a0: Double, to a1: Double) {
        guard a1 > a0 else { return }
        let steps = max(2, Int((a1 - a0) / (.pi / 48)))
        for i in 0 ... steps {
            let a = a0 + (a1 - a0) * Double(i) / Double(steps)
            let p = CGPoint(x: c.x + radius * CGFloat(cos(a)), y: c.y + radius * CGFloat(sin(a)))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
    }
}

// MARK: - ArcText
// Letters set along a circle, centred on twelve o'clock (`.top`, reading
// clockwise, tops outward) or six (`.bottom`, reading left to right, tops
// toward the centre — the way a coin's lower legend reads). Each glyph is
// its own `Text`, placed by its measured advance so the spacing is true.
private struct ArcText: View {

    enum Placement { case top, bottom }

    let text:      String
    let font:      UIFont
    let tracking:  CGFloat
    let radius:    CGFloat
    let placement: Placement

    /// Advance width of `text` set in `font` with `tracking` — the arc
    /// length the inscription needs.
    static func width(of text: String, font: UIFont, tracking: CGFloat) -> CGFloat {
        text.reduce(0) { $0 + advance(of: $1, font: font, tracking: tracking) }
    }

    private static func advance(of ch: Character, font: UIFont, tracking: CGFloat) -> CGFloat {
        (String(ch) as NSString).size(withAttributes: [.font: font]).width + tracking
    }

    var body: some View {
        let glyphs = Array(text)
        let total  = Self.width(of: text, font: font, tracking: tracking) - tracking
        let span   = Double(total / radius)
        let r      = Double(radius)
        // Running arc length to each glyph's centre.
        var cursor: CGFloat = 0
        let centres: [CGFloat] = glyphs.map { ch in
            let w = Self.advance(of: ch, font: font, tracking: tracking)
            defer { cursor += w }
            return cursor + (w - tracking) / 2
        }

        ZStack {
            ForEach(Array(glyphs.enumerated()), id: \.offset) { i, ch in
                let along = Double(centres[i]) / r
                // Top: start left of twelve and run clockwise; glyph up =
                // outward. Bottom: start left of six and run anticlockwise
                // (left to right on screen); glyph up = inward.
                let angle = placement == .top ? -.pi / 2 - span / 2 + along
                                              :  .pi / 2 + span / 2 - along
                let turn  = placement == .top ? angle + .pi / 2 : angle - .pi / 2
                Text(String(ch))
                    .font(Font(font))
                    .fixedSize()
                    .rotationEffect(.radians(turn))
                    .offset(x: radius * CGFloat(cos(angle)), y: radius * CGFloat(sin(angle)))
            }
        }
    }
}

// MARK: - LookArmingRing
// The overhead hold, made visible: the crosshair's ring drawing itself
// round from the top over exactly the arming time. Closes → the window
// opens; lower the phone first and it simply disappears.
private struct LookArmingRing: View {

    let duration: Double
    @State private var progress: CGFloat = 0

    var body: some View {
        let a = Artist.shared
        let d = a.crosshairRadius * 2
        Circle()
            .trim(from: 0, to: progress)
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: a.crosshairLineWidth * 1.5,
                                                          lineCap: .round))
            .rotationEffect(.degrees(-90))            // start at twelve o'clock
            .frame(width: d, height: d)
            .shadow(color: a.canvasBackground, radius: 2)
            .onAppear {
                withAnimation(.linear(duration: duration)) { progress = 1 }
            }
    }
}
