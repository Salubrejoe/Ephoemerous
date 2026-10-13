import SwiftUI

// MARK: - OrlojOverlay
// The Orloj widget's instrument laid over the live sky, in real Liquid
// Glass. The same face (`OrlojFace`), drawn through the APP's camera
// (`OrlojFace(riding:)`), so it lands star for star on the NorthOUT chart
// beneath and rides every pan, pinch and turn — the stack's parent
// transform carries it like any other layer.
//
// The widget hand-builds its glass because `.glassEffect` can't render
// there (see OrlojGlass.swift). The app can, so here every piece is the
// real material, bending the real sky. No plate, no stars of its own:
// the app's sky IS the plate.
//
// Equatable on its inputs: a gesture frame rebuilds `SkyFrame` but never
// the face — it rebuilds only when the committed camera, the date or the
// place moves.
struct OrlojOverlay: View, Equatable {
    let camera:    SkyCamera
    let date:      Date
    let latitude:  Angle
    let longitude: Angle

    /// The place's own clock, like the widget's — the phone's until the
    /// geocoder answers.
    @State private var timeZone: TimeZone = .current

    static func == (l: Self, r: Self) -> Bool {
        l.camera    == r.camera
            && l.date      == r.date
            && l.latitude  == r.latitude
            && l.longitude == r.longitude
    }

    var body: some View {
        let face = OrlojFace(riding:    camera,
                             date:      date,
                             latitude:  latitude,
                             longitude: longitude,
                             timeZone:  timeZone)
        let sun  = Artist.shared.palette.sun
        let moon = Artist.shared.palette.moon
        let ground = face.groundPath(),     land  = face.groundLandPath()
        let crown  = face.numeralCrownPath()
        let rete   = face.reteGlassPath(withStarHand: true, carvesGlyphs: true)
        let moonHand = face.moonCapsulePath(), moonLit = face.moonLitPath()
        let sunHand  = face.sunCapsulePath(),  sunLit  = face.sunBadgePath()
        ZStack {
            // The Earth below the horizon — clear seas, frosted land. Two
            // heights: in one container the land would melt into the sea.
            height([(ground, .clear)])
            height([(land,   .regular)])
            // The outer tropic and its numerals, one piece.
            height([(crown,  .regular)])
            // The rete — band, cross, hub, star hand.
            height([(rete,   .clear)])
            // The hands, fused at the axle; their badges ride above them.
            height([(moonHand, .regular),
                    (sunHand,  .regular)])
            height([(moonLit,  .regular.tint(moon.top)),
                    (sunLit,   .regular.tint(sun.top))])
        }
        .frame(width: camera.size.width, height: camera.size.height)
        .allowsHitTesting(false)
        .task(id: Place(latitude: latitude.degrees, longitude: longitude.degrees)) {
            timeZone = await LocalityResolver.shared.timeZone(lat: latitude.degrees,
                                                              lon: longitude.degrees) ?? .current
        }
    }

    /// One height of glass: its pieces in one container (Liquid Glass
    /// renders a container in a single pass), framed to the pieces' own
    /// bounds, clipped to the canvas. NEVER the whole oversized canvas —
    /// real glass keeps several buffers the size of its view, and eight
    /// canvas-sized pieces ran Gidan out of memory (3.4 GB, then jetsam).
    @ViewBuilder
    private func height(_ pieces: [(path: Path?, glass: Glass)]) -> some View {
        let shown = pieces.compactMap { p in p.path.map { (path: $0, glass: p.glass) } }
        if let box = bounds(of: shown.map(\.path)) {
            GlassEffectContainer(spacing: 0) {
                ZStack {
                    ForEach(shown.indices, id: \.self) { i in
                        Color.clear.glassEffect(shown[i].glass,
                                                in: OrlojPath(source: shown[i].path
                                                    .offsetBy(dx: -box.minX, dy: -box.minY)))
                    }
                }
                .frame(width: box.width, height: box.height)
            }
            .position(x: box.midX, y: box.midY)
        }
    }

    /// The pieces' bounds with a breath for the rim light, clipped to the
    /// canvas; nil when nothing lands on it.
    private func bounds(of paths: [Path]) -> CGRect? {
        let canvas = CGRect(origin: .zero, size: camera.size)
        let box    = paths.reduce(CGRect.null) { $0.union($1.boundingRect) }
                          .insetBy(dx: -2, dy: -2)
                          .intersection(canvas)
                          .integral
        return box.isNull || box.isEmpty ? nil : box
    }

    private struct Place: Equatable {
        let latitude, longitude: Double
    }
}
