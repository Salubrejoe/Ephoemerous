import SwiftUI

// MARK: - OrlojOverlay
// The Orloj widget's instrument laid over the live sky. The same face
// (`OrlojFace`), drawn through the APP's camera (`OrlojFace(riding:)`),
// so it lands star for star on the NorthOUT chart beneath and rides every
// pan, pinch and turn — the stack's parent transform carries it like any
// other layer.
//
// The glass is the widget's own, hand-built (`OrlojGlassLayers`), RENDERED
// INTO A BITMAP, and only when it must be:
//   • never while the sky moves — a gesture, or its glide, only carries the
//     picture already drawn (see `placement`), stretched and turned with
//     the sky;
//   • once the sky has rested a beat, and only if something the picture
//     shows has changed — a pan moves the whole instrument, so it needs
//     none;
//   • while time is scrubbed, the parts are turned apart (see `Picture.turn`)
//     — true for the dial and rete at any span, but a hand's badge also
//     slides along its hand with the season (the Sun's declination, the
//     Moon's), which no turn can fake: past `turnTruth` the hands ALONE are
//     redrawn, quick (no frost, no shadow), so they stay on the sky's own
//     Sun and Moon. The full glass comes back once the scrub settles.
// The Sun and Moon themselves are the sky's own POI labels, laid over the
// glass (see `SkyLayerStack`); the hands carry only a bulge round each.
// A render costs the main thread up to a second or more on an iPad (the
// fused crown is dear to draw), so the rule is: as few as possible, never
// under a finger.
//
// Two dearer ways were tried first — real `.glassEffect` (commit 3f40fbe)
// re-samples the sky every frame it moves and ran Gidan out of memory; a
// `.drawingGroup()` kept the glass's blurs live and panned at 4 fps.
struct OrlojOverlay: View, Equatable {
    let camera:    SkyCamera
    let date:      Date
    let latitude:  Angle
    let longitude: Angle
    /// The sky is at rest — no finger on it, nothing gliding.
    let resting:   Bool
    /// Time is being scrubbed (the ruler) — the picture's parts are turned,
    /// only the hands redrawn, until it settles.
    var scrubbing: Bool = false

    /// The place's own clock, like the widget's — the phone's until the
    /// geocoder answers.
    @State private var timeZone: TimeZone = .current
    /// The instrument as last rendered.
    @State private var picture:  Picture?
    /// The hands alone, redrawn quick while time is scrubbed — they stand
    /// in for the picture's own until it is redrawn. And when.
    @State private var hands:    Picture?
    @State private var lastHands: Date = .distantPast

    @Environment(\.displayScale)    private var displayScale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// How long the sky must rest before the picture is redrawn. ▼ TWEAK ▼
    private static let settle: Duration = .milliseconds(300)
    /// How far turning the hands stays true, and how often a scrub may
    /// redraw them past it. ▼ TWEAK ▼
    private static let turnTruth:   TimeInterval = 6 * 3600
    private static let handsRedraw: TimeInterval = 0.08

    /// The widest picture, in pixels. Past it — deep zoom — only the canvas
    /// is drawn, and a pan has to redraw. ▼ TWEAK ▼
    private static let maxSide: CGFloat = 4096

    static func == (l: Self, r: Self) -> Bool {
        l.camera    == r.camera
            && l.date      == r.date
            && l.latitude  == r.latitude
            && l.longitude == r.longitude
            && l.resting   == r.resting
            && l.scrubbing == r.scrubbing
    }

    var body: some View {
        ZStack {
            if let picture { carried(picture, showing: hands == nil ? .all : [.dial, .rete]) }
            if let hands   { carried(hands) }
        }
        .frame(width: camera.size.width, height: camera.size.height)
        .allowsHitTesting(false)
        .task(id: Inputs(of: self)) { await redraw() }
        .task(id: Place(latitude: latitude.degrees, longitude: longitude.degrees)) {
            timeZone = await LocalityResolver.shared.timeZone(lat: latitude.degrees,
                                                              lon: longitude.degrees) ?? .current
        }
    }

    /// A picture's parts, each turned on by the time since it was drawn —
    /// the rete with the sky, each hand with its body — and the whole
    /// carried with the sky.
    private func carried(_ picture: Picture, showing shown: OrlojParts = .all) -> some View {
        let place = placement(of: picture)
        return ZStack {
            ForEach(picture.parts.indices, id: \.self) { i in
                if shown.contains(picture.parts[i].part) {
                    Image(decorative: picture.parts[i].image, scale: displayScale)
                        .rotationEffect(picture.turn(picture.parts[i].part, to: date),
                                        anchor: picture.pole)
                }
            }
        }
        .scaleEffect(place.scale)
        .rotationEffect(place.rotation)
        .position(place.centre)
    }

    // MARK: Rendering

    /// Redraw if the sky is at rest and the picture no longer shows it —
    /// or, while time is scrubbed, just the hands once turning them would
    /// lie.
    private func redraw() async {
        let wanted = Inputs(of: self)
        guard resting else { return }
        if scrubbing {
            guard let picture else { return }
            let drawn = hands?.inputs.date ?? picture.inputs.date
            guard abs(date.timeIntervalSince(drawn)) > Self.turnTruth else { return }
            // Held back, not dropped: a pause mid-scrub still lands true.
            let wait = Self.handsRedraw - Date.now.timeIntervalSince(lastHands)
            if wait > 0 {
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled else { return }
            }
            renderHands(wanted)
            return
        }
        if let picture, hands == nil, picture.shows(wanted) { return }
        if picture != nil {
            try? await Task.sleep(for: Self.settle)
            guard !Task.isCancelled else { return }
        }
        render(wanted)
    }

    /// The whole instrument, in full glass.
    private func render(_ inputs: Inputs) {
        #if DEBUG
        let started = Date.now
        #endif
        guard let drawn = draw([.dial, .rete, .moonHand, .sunHand], quick: false, for: inputs)
        else { return }
        picture = drawn
        hands   = nil
        #if DEBUG
        MemoryLog.note(String(format: "orloj rendered  %4.0f ms  %.0f×%.0f pt%@",
                              Date.now.timeIntervalSince(started) * 1000,
                              drawn.box.width, drawn.box.height, drawn.whole ? "" : "  (clipped)"))
        #endif
    }

    /// The Sun's and Moon's hands alone, quick.
    private func renderHands(_ inputs: Inputs) {
        #if DEBUG
        let started = Date.now
        #endif
        lastHands = .now
        guard let drawn = draw([.moonHand, .sunHand], quick: true, for: inputs) else { return }
        hands = drawn
        #if DEBUG
        MemoryLog.note(String(format: "orloj hands     %4.0f ms",
                              Date.now.timeIntervalSince(started) * 1000))
        #endif
    }

    /// Draw parts of the face into bitmaps the size of the instrument. The
    /// face is built through a copy of the camera shifted so the
    /// instrument's box IS its canvas — nothing outside the box is laid
    /// out at all.
    private func draw(_ parts: [OrlojParts], quick: Bool, for inputs: Inputs) -> Picture? {
        let face = OrlojFace(riding: camera, date: date, latitude: latitude,
                             longitude: longitude, timeZone: timeZone)
        guard let (box, whole) = frame(of: face) else { return nil }
        var local    = camera
        local.size   = box.size
        local.offset = CGSize(width:  camera.offset.width  + camera.size.width  / 2 - box.midX,
                              height: camera.offset.height + camera.size.height / 2 - box.midY)
        var drawn = OrlojFace(riding: local, date: date, latitude: latitude,
                              longitude: longitude, timeZone: timeZone)
        drawn.skyLabels = labelSizes
        // One picture a part, so time can turn them apart (see `OrlojParts`).
        let images = parts.compactMap { part -> (part: OrlojParts, image: CGImage)? in
            let renderer = ImageRenderer(content:
                OrlojGlassLayers(face: drawn, onSky: true, quick: quick, parts: part)
                    .frame(width: box.width, height: box.height)
                    .environment(\.colorScheme, .dark))
            renderer.scale = displayScale
            return renderer.cgImage.map { (part, $0) }
        }
        guard images.count == parts.count else { return nil }
        return Picture(parts: images, box: box, inputs: inputs, whole: whole,
                       sense: drawn.hourSense,
                       pole: UnitPoint(x: drawn.center.x / box.width,
                                       y: drawn.center.y / box.height))
    }

    /// The Sun's and Moon's POI labels across, as `POILabelView` draws
    /// them — the hands' bulges are cut to fit round them.
    private var labelSizes: (sun: CGFloat, moon: CGFloat) {
        let a    = Artist.shared
        let type = a.typeScale(dynamicTypeSize)
        return (a.poiStyle(for: .sun).badgeSize * type, a.poiStyle(for: .moon).badgeSize * type)
    }

    /// The instrument's square — the numerals' ring, their height and a
    /// margin for the shadows. Whole, so a pan only moves it, unless that
    /// passes the pixel budget; then just the part on the canvas.
    private func frame(of face: OrlojFace) -> (box: CGRect, whole: Bool)? {
        let reach  = face.numeralRadius
                   + OrlojFace.glassNumeralSize(ui: face.ui, type: face.type)
                   + 8 * face.ui
        let square = CGRect(x: face.center.x - reach, y: face.center.y - reach,
                            width: 2 * reach, height: 2 * reach).integral
        if square.width * displayScale <= Self.maxSide { return (square, true) }
        let clipped = square.intersection(CGRect(origin: .zero, size: camera.size)).integral
        return clipped.isNull || clipped.isEmpty ? nil : (clipped, false)
    }

    /// Where a picture drawn for one camera belongs under the current one.
    /// Pan, pinch and turn move the NorthOUT sky as one similarity about
    /// the pole, so the picture is scaled, turned and carried with it.
    private func placement(of picture: Picture) -> (centre: CGPoint, scale: CGFloat, rotation: Angle) {
        let was   = picture.inputs.camera
        let k     = was.scale > 0 ? camera.scale / was.scale : 1
        let turn  = camera.rotation - was.rotation
        let c     = CGFloat(cos(turn.radians)), s = CGFloat(sin(turn.radians))
        let from  = was.screen(.zero), to = camera.screen(.zero)
        let d     = CGPoint(x: picture.box.midX - from.x, y: picture.box.midY - from.y)
        return (CGPoint(x: to.x + k * (d.x * c - d.y * s),
                        y: to.y + k * (d.x * s + d.y * c)),
                k, turn)
    }

    // MARK: Values

    private struct Picture {
        let parts:  [(part: OrlojParts, image: CGImage)]
        let box:    CGRect
        let inputs: Inputs
        /// The whole instrument, not a canvas-sized cut of it.
        let whole:  Bool
        /// Which way hour angles run on screen, and where the axle sits in
        /// the box — what time turns the parts by, and about.
        let sense:  Double
        let pole:   UnitPoint

        /// Still a true picture of `wanted`: the same, or — when whole —
        /// differing only by a pan.
        func shows(_ wanted: Inputs) -> Bool {
            inputs == wanted || (whole && inputs.panned == wanted.panned)
        }

        /// Seconds per turn of the sky, the Sun's hand and the Moon's.
        private static let sidereal = 86_164.1, solar = 86_400.0, lunar = 89_428.3

        /// How far a part has turned by `date` since it was drawn.
        func turn(_ part: OrlojParts, to date: Date) -> Angle {
            let period: Double
            switch part {
            case .sky, .rete: period = Self.sidereal
            case .sunHand:    period = Self.solar
            case .moonHand:   period = Self.lunar
            default:          return .zero
            }
            return .radians(sense * 2 * .pi * date.timeIntervalSince(inputs.date) / period)
        }
    }

    /// Everything the picture depends on — a change may redraw it.
    private struct Inputs: Equatable {
        var camera:    SkyCamera
        var date:      Date
        var latitude:  Angle
        var longitude: Angle
        var timeZone:  TimeZone
        var resting:   Bool
        var scrubbing: Bool

        init(of overlay: OrlojOverlay) {
            camera    = overlay.camera
            date      = overlay.date
            latitude  = overlay.latitude
            longitude = overlay.longitude
            timeZone  = overlay.timeZone
            resting   = overlay.resting
            scrubbing = overlay.scrubbing
        }

        /// The same inputs with the pan taken out, at rest.
        var panned: Inputs {
            var copy = self
            copy.camera.offset = .zero
            copy.resting       = true
            copy.scrubbing     = false
            return copy
        }
    }

    private struct Place: Equatable {
        let latitude, longitude: Double
    }
}
