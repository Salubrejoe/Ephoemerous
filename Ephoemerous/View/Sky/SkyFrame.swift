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

    /// Figure stars carrying a Bayer letter and NOTHING else — no proper
    /// name to print, so the letter is all they can be called. These get
    /// the quiet Greek glyph (`BayerLabels`); a star with a proper name is
    /// deliberately excluded, because it already gets a full POI label and
    /// two marks on one star is the overlap rule broken.
    static let bayerFigureStars: [Star] =
        ConstellationLines.shared.figureStars
            .filter { $0.properName == nil && $0.bayerLetter != nil }

    // The camera the frozen Canvases draw through.
    let camera:      SkyCamera
    let canvasSize:  CGSize
    /// The visible window inside the overdraw margin — cartography fades
    /// curved words against this, not against the oversized canvas.
    let visibleRect: CGRect

    /// How far the sky has opened into LOOK mode, 0 = chart, 1 = window.
    let lookBlend: Double

    // Live gesture transform. `applied` is the parent `.offset`.
    let effPinch:  CGFloat
    let liveScale: CGFloat
    let liveRot:   Angle
    let applied:   CGSize
    /// Where unpromoted names may speak — see `LabelComfortZone`.
    let comfort:   LabelComfortZone

    // Who is selected — passive labels defer to the promoted pin.
    let selection:       SkyObject?
    let selectedStarID:  String?
    let selectedConsID:  String?

    // Which stars each layer owns, so no star is drawn twice.
    let favouriteIDs: Set<String>
    let namedOnly:    [Star]
    let namedIDs:     Set<String>
    /// Bayer-lettered figure stars minus any the user has favourited —
    /// a favourite already wears its own badge and name.
    let bayerOnly:    [Star]
    let favouriteConstellationTints: [Constellation: Color]
    /// Which star labels give way so none overlap — see `StarLabelLayout`.
    let starLabels: StarLabelLayout

    @MainActor
    init(app: AppState,
         sky: MainGestureCoordinator,
         geoSize: CGSize,
         overdraw: CGFloat,
         compassEngage: Double,
         morphScaleFrom: CGFloat,
         morphOffsetFrom: CGSize,
         typeSize: DynamicTypeSize = .large) {

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
        // The window owns the view as well — no live spin under it.
        liveRot            = (inCompass || app.lookBlend > 0) ? .zero : sky.liveRotation

        // Compass mode ROTATES the sky and nothing else. It used to reframe
        // as well — puck low, horizon high, an AR-ish pose — which meant
        // toggling it zoomed the canvas out from under you. The heading is
        // the whole point; the framing was an opinion on top of it, and one
        // that fought whatever zoom you had chosen. `compassCameraFraming`
        // survives for the share card's own AR pose.
        let engaging = compassEngage > 0.0001

        // NorthIN↔NorthOUT reframe rides the SAME clock-driven progress as
        // the projection morph, so zoom and eye-slerp stay in lockstep. At
        // rest progress = 1 and this collapses to the plain `sky` values.
        let mp        = app.perspectiveMorphProgress
        let baseScale = morphScaleFrom         + (sky.scale         - morphScaleFrom)         * mp
        let baseOffW  = morphOffsetFrom.width  + (sky.offset.width  - morphOffsetFrom.width)  * mp
        let baseOffH  = morphOffsetFrom.height + (sky.offset.height - morphOffsetFrom.height) * mp

        // LOOK mode: as the phone lifts, the chart opens into a window. The
        // projection slides its line of sight to the phone's (see
        // `Projection.Viewpoint.look`); here the framing follows — zoom
        // eases (in log space, so it feels even) to the window's field of
        // view, the pan and the chart rotation ease out. At blend 0 every
        // value below is exactly the chart's.
        let viewpoint = app.viewpoint
        let look      = viewpoint.look?.blend ?? 0
        lookBlend     = look
        let lookScale = Artist.shared.lookScale(screenHeight: geoSize.height)
        let scale     = look > 0 ? exp(log(baseScale) + (log(lookScale) - log(baseScale)) * look) : baseScale

        camera = SkyCamera(
            scale:     scale,
            offset:    CGSize(width: baseOffW * (1 - look), height: baseOffH * (1 - look)),
            rotation:  .radians(cameraRotation.radians * (1 - look)),
            size:      canvasSize,
            viewpoint: viewpoint,
            sidereal:  app.localSiderealOffset)

        // While the compass framing — or the window — is in play it is
        // baked into the camera and touch is off, so the live transform is
        // identity — labels take the camera scale for their tiers and stay
        // put (no counter-drift).
        let baked = engaging || look > 0
        effPinch  = baked ? 1            : sky.effPinch
        liveScale = baked ? camera.scale : sky.liveScale
        applied   = baked ? .zero        : sky.applied
        comfort   = LabelComfortZone(pivot:    CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2),
                                     visible:  visibleRect,
                                     pinch:    effPinch,
                                     rotation: liveRot,
                                     offset:   applied)

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
        bayerOnly    = Self.bayerFigureStars.filter { !favIDs.contains($0.id) }

        // One neutral constellation colour now (the myth taxonomy is retired).
        favouriteConstellationTints = Dictionary(uniqueKeysWithValues:
            app.favouriteConstellations.map { ($0, Color.tertiary) })

        starLabels = StarLabelLayout(camera:     camera,
                                     scale:      liveScale,
                                     comfort:    comfort,
                                     date:       app.renderedObservationDate,
                                     favourites: app.favouriteStars,
                                     named:      namedOnly,
                                     selection:  picked,
                                     typeSize:   typeSize)
    }
}
