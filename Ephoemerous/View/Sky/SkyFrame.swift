import SwiftUI

// MARK: - SkyFrame
// Everything the sky's layers need for ONE rendered frame, resolved once.
//
// This used to be ~90 lines of local `let`s at the top of `MainView.body`,
// which meant the trickiest reasoning in the app — camera composition, the
// compass blend, the morph glide, which labels to suppress — was buried
// inside a view builder where it couldn't be read on its own or reasoned
// about apart from the layout.
//
// It is a plain value: give it the app state, the gesture camera and the
// geometry, and it computes. No view, no side effects.
struct SkyFrame {

    /// Only PROPER-named stars (Sirius, Betelgeuse…) get the POI label.
    /// Computed ONCE — `workableStars` is ~3k structs and several layers
    /// read it per frame.
    static let properNamedStars: [Star] =
        StarDatabase.shared.workableStars.filter { $0.properName != nil }

    // The camera the frozen Canvases draw through.
    let camera:      SkyCamera
    let canvasSize:  CGSize
    /// The visible window inside the overdraw margin — cartography fades
    /// curved words against this, not against the oversized canvas.
    let visibleRect: CGRect

    // Live gesture transform. `applied` is the parent `.offset`.
    let effPinch:  CGFloat
    let liveScale: CGFloat
    let liveRot:   Angle
    let applied:   CGSize

    // Who is selected — passive labels defer to the promoted pin.
    let selection:       SkyObject?
    let selectedStarID:  String?
    let selectedConsID:  String?

    // Which stars each layer owns, so no star is drawn twice.
    let favouriteIDs: Set<String>
    let namedOnly:    [Star]
    let namedIDs:     Set<String>
    let favouriteConstellationTints: [Constellation: Color]

    @MainActor
    init(app: AppState,
         sky: MainGestureCoordinator,
         geoSize: CGSize,
         overdraw: CGFloat,
         compassEngage: Double,
         morphScaleFrom: CGFloat,
         morphOffsetFrom: CGSize) {

        // The canvas is drawn OVERSIZE — the screen plus `overdraw` on every
        // edge — and centred. A SwiftUI Canvas clips to its own frame, so a
        // screen-sized one would slide in blank at the trailing edge the
        // instant the parent transform pans it.
        canvasSize  = CGSize(width:  geoSize.width  + overdraw * 2,
                             height: geoSize.height + overdraw * 2)
        visibleRect = CGRect(x: overdraw, y: overdraw,
                             width: geoSize.width, height: geoSize.height)

        // Compass (heading-up) mode: the device heading OWNS the rotation.
        // NEGATED because `SkyCamera.screen` rotates AFTER the y-flip while
        // `renderedRotation` is tuned for a pre-flip rotation — without it,
        // heading-up spins the wrong way (face east → west up).
        let inCompass      = app.compassMode
        let cameraRotation = inCompass ? Angle.radians(-app.renderedRotation.radians)
                                       : sky.rotation
        liveRot            = inCompass ? .zero : sky.liveRotation

        // Compass mode also FRAMES the sky (puck low, horizon high).
        // `compassEngage` eases 0→1 so the camera GLIDES into the pose
        // instead of snapping. Pure view-time blend — the committed `sky`
        // camera is never touched, so leaving compass restores the exact
        // view you were on.
        let framing  = app.compassCameraFraming(screenHeight: geoSize.height)
        let t        = compassEngage
        let engaging = t > 0.0001

        // NorthIN↔NorthOUT reframe rides the SAME clock-driven progress as
        // the projection morph, so zoom and eye-slerp stay in lockstep. At
        // rest progress = 1 and this collapses to the plain `sky` values.
        let mp        = app.perspectiveMorphProgress
        let baseScale = morphScaleFrom         + (sky.scale         - morphScaleFrom)         * mp
        let baseOffW  = morphOffsetFrom.width  + (sky.offset.width  - morphOffsetFrom.width)  * mp
        let baseOffH  = morphOffsetFrom.height + (sky.offset.height - morphOffsetFrom.height) * mp

        camera = SkyCamera(
            scale:     baseScale + (framing.scale - baseScale) * t,
            offset:    CGSize(width:  baseOffW + (framing.offset.width  - baseOffW) * t,
                              height: baseOffH + (framing.offset.height - baseOffH) * t),
            rotation:  cameraRotation,
            size:      canvasSize,
            viewpoint: app.viewpoint,
            sidereal:  app.localSiderealOffset)

        // While the compass framing is in play it is baked into the camera
        // and touch is off, so the live transform is identity — labels take
        // the camera scale for their tiers and stay put (no counter-drift).
        effPinch  = engaging ? 1            : sky.effPinch
        liveScale = engaging ? camera.scale : sky.liveScale
        applied   = engaging ? .zero        : sky.applied

        // Source of truth is `detailDestination`, so a canvas tap, the
        // sheet's X and a swipe-away all stay in lockstep.
        let picked     = app.detailDestination
        selection      = picked
        selectedStarID = { if case .star(let s) = picked { return s.id }; return nil }()
        selectedConsID = { if case .constellation(let c) = picked { return c.rawValue }; return nil }()

        // A favourite that is ALSO proper-named would otherwise draw both a
        // `.followedStar` and a `.namedStar` badge — one label per star.
        let favIDs   = Set(app.favouriteStars.map(\.id))
        favouriteIDs = favIDs
        namedOnly    = Self.properNamedStars.filter { !favIDs.contains($0.id) }
        // The plain star field defers to these once their own mark takes over.
        namedIDs     = Set(namedOnly.map(\.id))

        // One neutral constellation colour now (the myth taxonomy is retired).
        favouriteConstellationTints = Dictionary(uniqueKeysWithValues:
            app.favouriteConstellations.map { ($0, Color.tertiary) })
    }
}
