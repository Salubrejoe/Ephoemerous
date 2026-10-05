import SwiftUI
import UIKit
import simd
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
// FIND: with an object selected, the ring hunts for it instead. Other
// stars stop stealing the lock; the target's name sits quietly in the top
// of the ring, the turn still to go (or "below horizon") in the bottom,
// and an accent arrow on the rim points the way. It locks — with a
// success tap — only when the target itself slides inside.
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
    /// The selected object — the one to FIND. `nil` = free looking.
    var target: SkyObject? = nil
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
            let ready  = blend >= a.crosshairLockBlend
            let hunt   = ready ? target.flatMap(hunt(for:)) : nil
            // Hunting: only the target may lock. Free: the nearest tappable.
            let locked = !ready ? nil : target == nil ? lock() : (hunt?.found == true ? target : nil)
            let font   = UIFont.systemFont(ofSize: a.labelFont(.caption2, design: .default, size: dynamicTypeSize).pointSize,
                                           weight: .semibold)
            let seeking = hunt != nil && locked == nil
            let ring   = Inscription(name:     (locked ?? (seeking ? target : nil))?.displayName,
                                     distance: seeking ? hunt?.remaining : locked?.distanceLabel(at: date),
                                     font:     font,
                                     tracking: a.crosshairTracking * type,
                                     radius:   (locked == nil && !seeking ? a.crosshairRadius : a.crosshairLockedRadius) * type)
            let ink    = locked == nil ? Color.primary.opacity(a.crosshairRestOpacity) : Color.accentColor
            // Seeking, the words are the destination, not a catch: quiet ink.
            let words  = locked == nil ? Color.primary.opacity(a.crosshairHuntOpacity) : Color.accentColor

            ZStack {
                GappedRing(radius:    ring.radius,
                           topGap:    ring.nameGap,
                           bottomGap: ring.distanceGap)
                    .stroke(ink, style: StrokeStyle(lineWidth: a.crosshairLineWidth, lineCap: .round))

                if let name = ring.name {
                    ArcText(text: name, font: font, tracking: ring.tracking,
                            radius: ring.radius, placement: .top)
                        .foregroundStyle(words)
                        .id(name)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                if let distance = ring.distance {
                    ArcText(text: distance, font: font, tracking: ring.tracking,
                            radius: ring.radius, placement: .bottom)
                        .foregroundStyle(words.opacity(a.crosshairDistanceOpacity))
                }
                if seeking, let bearing = hunt?.bearing {
                    // The way to turn — on the rim, outside the letters.
                    let r = ring.radius + a.crosshairArrowInset * type
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.system(size: a.crosshairArrowSize * type))
                        .foregroundStyle(Color.accentColor)
                        .rotationEffect(.radians(bearing + .pi / 2))
                        .offset(x: r * CGFloat(cos(bearing)), y: r * CGFloat(sin(bearing)))
                }
            }
            // Sized to the ring plus room for the letters — not the whole
            // canvas, which a bare Shape would claim (and shadow).
            .frame(width: (ring.radius + 24) * 2, height: (ring.radius + 24) * 2)
            .shadow(color: a.canvasBackground, radius: 2)
            // The ring opens from the top, the letters appearing in the gap.
            .animation(.snappy(duration: 0.35), value: locked?.id)
            .animation(.snappy(duration: 0.35), value: seeking)
            .position(centre)
            .opacity(blend)
            // A tick for a passing catch; a success tap for the one you hunted.
            .sensoryFeedback(.selection, trigger: locked?.id) { _, new in new != nil && target == nil }
            .sensoryFeedback(.success,   trigger: locked?.id) { _, new in new != nil && target != nil }
            .allowsHitTesting(false)
        }
    }

    // MARK: Find

    private struct Hunt {
        /// Inside the ring.
        let found:     Bool
        /// Screen bearing from the centre to the target (radians, y down) —
        /// on a window centred on your line of sight, exactly the way to turn.
        let bearing:   Double?
        /// What's left, for the bottom of the ring: degrees to turn, or
        /// "below horizon" when no turning will bring it into the sky.
        let remaining: String
    }

    /// Where the target is relative to the sight. The window is an
    /// azimuthal projection centred on the line of sight, so the screen
    /// direction to the target IS the direction to turn, and its distance
    /// from centre gives the angle left (ρ = 2·tan(θ/2)).
    private func hunt(for target: SkyObject) -> Hunt? {
        let radius = Artist.shared.crosshairRadius * Artist.shared.typeScale(dynamicTypeSize)
        let below  = SkyLabObjects.rotatedVector(target, camera: camera, date: date)
            .map { simd_dot($0, camera.viewpoint.originVector) < 0 } ?? false

        guard let p = SkyLabObjects.screen(target, camera: camera, date: date) else {
            // Dead behind you — the one point the window can't place.
            return Hunt(found: false, bearing: nil, remaining: "180°")
        }
        let dx = p.x - centre.x, dy = p.y - centre.y
        let d  = hypot(dx, dy)
        let degrees = Int((2 * atan(Double(d / camera.scale) / 2) * 180 / .pi).rounded())
        return Hunt(found:     d <= radius,
                    bearing:   d > 0.5 ? atan2(Double(dy), Double(dx)) : nil,
                    remaining: below ? String(localized: "Below horizon") : "\(degrees)°")
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
