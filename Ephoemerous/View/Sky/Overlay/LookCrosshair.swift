import SwiftUI
import LoreKit

// MARK: - LookCrosshair
// LOOK mode's sight (see `Artist+Aim`): a ring FIXED at the screen's
// centre while the sky moves under it with the hand — the window model,
// where the phone's back is the only thing that points. Anything you could
// tap — a named star, a planet, the Moon — that slides inside LOCKS: the
// ring takes the accent ("live / engaged"), a selection tick, its name.
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

    var body: some View {
        if app.isArmingLook {
            LookArmingRing(duration: app.lookArmDuration)
                .position(centre)
                .allowsHitTesting(false)
        }
        if blend > 0.01 {
            let a      = Artist.shared
            let locked = blend >= a.crosshairLockBlend ? lock() : nil
            let ink    = locked == nil ? Color.primary.opacity(a.crosshairRestOpacity) : Color.accentColor
            let d      = a.crosshairRadius * 2

            ZStack {
                Circle()
                    .stroke(ink, lineWidth: a.crosshairLineWidth)
                    .frame(width: d, height: d)
                    .shadow(color: a.canvasBackground, radius: 2)
                if let locked {
                    Text(locked.displayName)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .shadow(color: a.canvasBackground, radius: 2)
                        .fixedSize()
                        .offset(y: a.crosshairRadius + a.crosshairNameGap + 8)
                        .transition(.opacity)
                }
            }
            .animation(.snappy(duration: 0.2), value: locked?.id)
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
        let radius = Artist.shared.crosshairRadius
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
