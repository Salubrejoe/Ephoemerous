import SwiftUI

// MARK: - MainView + selection
// What happens between a finger and a selected object: hit-testing a tap
// against what is actually on screen, and gliding the chosen object into
// the comfort zone above the sheet.
//
// Split out of `MainView` because it is logic, not layout — none of it
// builds a view, and reading the body shouldn't mean scrolling past it.
extension MainView {

    // MARK: - Tap → select + comfort-zone pan

    /// Builds the tap handler stored on the coordinator. The closure
    /// captures the live `app` (a reference) and rebuilds the camera from
    /// the coordinator's CURRENT committed state at tap time, so it always
    /// hit-tests against what's on screen.
    func makeTapHandler() -> (CGPoint) -> Void {
        let overdraw = self.overdraw
        let app      = self.app
        return { [weak sky] loc in
            guard let sky else { return }
            // Only act at rest — otherwise interrupt the in-flight fling
            // (so the tap stops the slide) and let the next tap select.
            guard sky.isResting else { sky.settleNow(); return }

            // Screen + canvas geometry, reconstructed from the coordinator.
            let geoSize = CGSize(width: sky.center.x * 2, height: sky.center.y * 2)
            guard geoSize.width > 0, geoSize.height > 0 else { return }
            let canvasSize = CGSize(width:  geoSize.width  + overdraw * 2,
                                    height: geoSize.height + overdraw * 2)
            let camera = SkyCamera(scale:     sky.scale,
                                      offset:    sky.offset,
                                      rotation:  sky.rotation,
                                      size:      canvasSize,
                                      viewpoint: app.viewpoint,
                                      sidereal:  app.localSiderealOffset)

            // Only LABELLED objects are tappable — respect the tiers, so the
            // tap target set grows exactly as the labels reveal with zoom.
            // Gathers every kind (star / sun / moon / planet / constellation)
            // gated by the SAME threshold its label overlay obeys, projects
            // each, and picks the nearest within the touch radius. Canvas
            // points are oversized → subtract `overdraw` for screen space.
            let scale = sky.scale
            let date  = app.renderedObservationDate
            let a     = Artist.shared

            var cands: [(obj: SkyObject, screen: CGPoint)] = []
            func consider(_ obj: SkyObject, gate: Bool) {
                guard gate, let cp = SkyLabObjects.screen(obj, camera: camera, date: date) else { return }
                cands.append((obj, CGPoint(x: cp.x - overdraw, y: cp.y - overdraw)))
            }

            // Stars — each gated by its own badge tier (favourites at 70,
            // proper-named deeper, per-star by magnitude). A favourite that's
            // also proper-named is tested once, as followed.
            let favIDs = Set(app.favouriteStars.map(\.id))
            for star in app.favouriteStars {
                consider(.star(star), gate: scale >= a.poiStyle(for: .followedStar(star)).badgeIn)
            }
            for star in SkyFrame.properNamedStars where !favIDs.contains(star.id) {
                consider(.star(star), gate: scale >= a.poiStyle(for: .namedStar(star)).badgeIn)
            }

            // Solar-system bodies — Sun / Moon always (badgeIn 0), planets
            // past their badge tier.
            consider(.sun,  gate: true)
            consider(.moon, gate: true)
            for (planet, _, _, _) in PlanetPosition.allVectors(for: date, siderealOffset: camera.sidereal) {
                consider(.planet(planet), gate: scale >= a.poiStyle(for: .planet(planet)).badgeIn)
            }

            // Constellation names — tappable once the name tier reveals.
            let consTextIn = a.poiStyle(for: .constellation).textIn
            if scale >= consTextIn {
                for (cons, _) in ConstellationLines.shared.labelAnchors {
                    consider(.constellation(cons), gate: true)
                }
            }

            let tapRadius: CGFloat = 30
            var best: (obj: SkyObject, dist: CGFloat, screen: CGPoint)? = nil
            for (obj, s) in cands {
                let d = hypot(s.x - loc.x, s.y - loc.y)
                if d <= tapRadius, best == nil || d < best!.dist {
                    best = (obj, d, s)
                }
            }
            // Tapped empty sky → deselect (animated demotion + sheet
            // dismiss). Only act if something is selected, so an idle tap on
            // empty sky doesn't thrash state.
            guard let hit = best else {
                if app.detailDestination != nil {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        app.detailDestination = nil
                    }
                }
                return
            }

            // Promote: springs the label in + raises the detail sheet. A
            // picker owns the bottom slot first — close it so the sheet can
            // take over. The comfort-zone pan is driven by `onChange(of:
            // detailDestination)` so a search pick pans too.
            app.isShowingLocationPicker = false
            app.isShowingDatePicker     = false

            let promote = { (obj: SkyObject) in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    app.detailDestination = obj
                }
            }
            // A DIFFERENT card is already up → tear it down and re-present
            // after a beat (production's `sheetSwapDelay`). Swapping the
            // sheet's item in place keeps the live presentation, and the new
            // card lands at the wrong (large) detent instead of the third;
            // `_sheetSwapping` hides search across the gap.
            if let current = app.detailDestination, current.id != hit.obj.id {
                app._sheetSwapping    = true
                app.detailDestination = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    app._sheetSwapping = false
                    promote(hit.obj)
                }
            } else {
                promote(hit.obj)
            }
        }
    }

    /// Reflect the SkyLab's rotation into `app.canvasRotation` so the rose
    /// (which reads `renderedRotation`) shows up when the canvas is twisted.
    /// Skipped in compass mode — there the heading owns `renderedRotation`.
    func mirrorRotationToRose() {
        guard !app.compassMode else { return }
        let mirrored = Angle.radians(-(sky.rotation.radians + sky.liveRotation.radians))
        if app.canvasRotation != mirrored { app.canvasRotation = mirrored }
    }

    // MARK: - Comfort-zone pan (any selection)

    /// Pan the selected object into the comfort zone — upper-third focus,
    /// 100pt no-pan radius; outside it, glide just to the circle's edge
    /// (minimal motion), mirroring production's `panFocus`. Driven off the
    /// selection (not the tap) so a SEARCH pick pans the same as a canvas
    /// tap. No-op if already comfy, mid-gesture, or the object is on the
    /// back of the sphere (can't pan-only to it — a slew would be needed).
    func panIntoComfortZone(_ obj: SkyObject) {
        guard sky.isResting else { return }
        let geoSize = CGSize(width: sky.center.x * 2, height: sky.center.y * 2)
        guard geoSize.width > 0, geoSize.height > 0 else { return }
        let canvasSize = CGSize(width:  geoSize.width  + overdraw * 2,
                                height: geoSize.height + overdraw * 2)
        let camera = SkyCamera(scale:     sky.scale,
                                  offset:    sky.offset,
                                  rotation:  sky.rotation,
                                  size:      canvasSize,
                                  viewpoint: app.viewpoint,
                                  sidereal:  app.localSiderealOffset)
        guard let cp = SkyLabObjects.screen(obj, camera: camera,
                                            date: app.renderedObservationDate) else { return }
        let objScreen = CGPoint(x: cp.x - overdraw, y: cp.y - overdraw)
        let focus = CGPoint(x: geoSize.width / 2, y: geoSize.height / 3)
        let dx = objScreen.x - focus.x
        let dy = objScreen.y - focus.y
        let dist = hypot(dx, dy)
        let comfortRadius: CGFloat = 100
        guard dist > comfortRadius else { return }

        // Land the object on the NEAREST point of the comfort circle —
        // `focus + R·û` — so it moves by `dist - R`. (Production's panFocus
        // instead nudges `R` toward the focus, which lands a near canvas-tap
        // inside the zone but barely shifts a FAR list pick — the "not enough
        // to move" bug.) Minimal motion for a near tap, as much as needed
        // for a far one.
        let k    = comfortRadius / dist
        let edge = CGPoint(x: focus.x + dx * k, y: focus.y + dy * k)
        sky.focusPan(dragTarget: CGSize(width:  edge.x - objScreen.x,
                                        height: edge.y - objScreen.y))
    }
}
