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
//     none.
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

    /// The place's own clock, like the widget's — the phone's until the
    /// geocoder answers.
    @State private var timeZone: TimeZone = .current
    /// The instrument as last rendered.
    @State private var picture:  Picture?

    @Environment(\.displayScale) private var displayScale

    /// How long the sky must rest before the picture is redrawn. ▼ TWEAK ▼
    private static let settle: Duration = .milliseconds(300)
    /// The widest picture, in pixels. Past it — deep zoom — only the canvas
    /// is drawn, and a pan has to redraw. ▼ TWEAK ▼
    private static let maxSide: CGFloat = 4096

    static func == (l: Self, r: Self) -> Bool {
        l.camera    == r.camera
            && l.date      == r.date
            && l.latitude  == r.latitude
            && l.longitude == r.longitude
            && l.resting   == r.resting
    }

    var body: some View {
        ZStack {
            if let picture {
                let place = placement(of: picture)
                Image(decorative: picture.image, scale: displayScale)
                    .scaleEffect(place.scale)
                    .rotationEffect(place.rotation)
                    .position(place.centre)
            }
        }
        .frame(width: camera.size.width, height: camera.size.height)
        .allowsHitTesting(false)
        .task(id: Inputs(of: self)) { await redraw() }
        .task(id: Place(latitude: latitude.degrees, longitude: longitude.degrees)) {
            timeZone = await LocalityResolver.shared.timeZone(lat: latitude.degrees,
                                                              lon: longitude.degrees) ?? .current
        }
    }

    // MARK: Rendering

    /// Redraw if the sky is at rest and the picture no longer shows it.
    private func redraw() async {
        let wanted = Inputs(of: self)
        guard resting else { return }
        if let picture, picture.shows(wanted) { return }
        if picture != nil {
            try? await Task.sleep(for: Self.settle)
            guard !Task.isCancelled else { return }
        }
        render(wanted)
    }

    /// Draw the face into a bitmap the size of the instrument. The face is
    /// built through a copy of the camera shifted so the instrument's box
    /// IS its canvas — nothing outside the box is laid out at all.
    private func render(_ inputs: Inputs) {
        #if DEBUG
        let started = Date.now
        #endif
        let face = OrlojFace(riding: camera, date: date, latitude: latitude,
                             longitude: longitude, timeZone: timeZone)
        guard let (box, whole) = frame(of: face) else { picture = nil; return }
        var local    = camera
        local.size   = box.size
        local.offset = CGSize(width:  camera.offset.width  + camera.size.width  / 2 - box.midX,
                              height: camera.offset.height + camera.size.height / 2 - box.midY)
        let drawn = OrlojFace(riding: local, date: date, latitude: latitude,
                              longitude: longitude, timeZone: timeZone)
        let renderer = ImageRenderer(content:
            OrlojGlassLayers(face: drawn, onSky: true)
                .frame(width: box.width, height: box.height)
                .environment(\.colorScheme, .dark))
        renderer.scale = displayScale
        guard let image = renderer.cgImage else { return }
        picture = Picture(image: image, box: box, inputs: inputs, whole: whole)
        #if DEBUG
        MemoryLog.note(String(format: "orloj rendered  %4.0f ms  %.0f×%.0f pt%@",
                              Date.now.timeIntervalSince(started) * 1000,
                              box.width, box.height, whole ? "" : "  (clipped)"))
        #endif
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
        let image:  CGImage
        let box:    CGRect
        let inputs: Inputs
        /// The whole instrument, not a canvas-sized cut of it.
        let whole:  Bool

        /// Still a true picture of `wanted`: the same, or — when whole —
        /// differing only by a pan.
        func shows(_ wanted: Inputs) -> Bool {
            inputs == wanted || (whole && inputs.panned == wanted.panned)
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

        init(of overlay: OrlojOverlay) {
            camera    = overlay.camera
            date      = overlay.date
            latitude  = overlay.latitude
            longitude = overlay.longitude
            timeZone  = overlay.timeZone
            resting   = overlay.resting
        }

        /// The same inputs with the pan taken out, at rest.
        var panned: Inputs {
            var copy = self
            copy.camera.offset = .zero
            copy.resting       = true
            return copy
        }
    }

    private struct Place: Equatable {
        let latitude, longitude: Double
    }
}
