import SwiftUI

struct GlassRing: View {
    let radius     : Double
    let lineWidth  : Double
    let tint       : Color
    
    init(radius: Double, lineWidth: Double, tint: Color = .clear) {
        self.radius = radius
        self.lineWidth = lineWidth
        self.tint = tint
    }
    
    var body: some View {
        Circle()
        //            .fill(tint)
            .frame(width: 2 * radius, height: 2 * radius)
            .glassEffect(.clear.tint(tint))
            .mask(
                Circle()
                    .frame(width: 2 * radius, height: 2 * radius)
                    .overlay(
                        Circle()
                            .frame(width: 2 * (radius - lineWidth), height: 2 * (radius - lineWidth))
                            .blendMode(.destinationOut)
                    )
                    .compositingGroup()
            )
    }
}
struct Ring: View {
    let radius     : Double
    let lineWidth  : Double
    let tint       : Color
    
    init(radius: Double, lineWidth: Double, tint: Color = .clear) {
        self.radius = radius
        self.lineWidth = lineWidth
        self.tint = tint
    }

    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: 2 * radius, height: 2 * radius)
//            .glassEffect(.clear.tint(tint))
            .mask(
                Circle()
                    .frame(width: 2 * radius, height: 2 * radius)
                    .overlay(
                        Circle()
                            .frame(width: 2 * (radius - lineWidth), height: 2 * (radius - lineWidth))
                            .blendMode(.destinationOut)
                    )
                    .compositingGroup()
            )
    }
}

struct WatchMaskView: View {
    @Environment(\.colorScheme) var cS
    @Environment(EAppState.self) var state

    // Crown parallels — small-circle offsets from the observer latitude.
    private static let parallelOffsets: [Angle] = [
        .radians(0.1), .radians(0.0), .radians(-0.1), .radians(-0.2), .radians(-0.31)
    ]

    var body: some View {
        // Derive the projection straight from state every render. The old
        // code mirrored scale/latitude into an @State SProjection via
        // .onChange, which runs *after* the pass that drew the canvas — so
        // the crown trailed the sky by one frame during pinch/drag. Pure
        // derivation keeps both layers in exact lockstep.
        let proj = SProjection(
            baseLatitude:    state.origin.latitude,
            scale:           2 * state.renderedScale,
            parallelOffsets: Self.parallelOffsets
        )
        return ZStack {
            let crownR = state.renderedScale * ENSWatchCrownLayer.clipRadius
            let ringW  = 4.0
            let outerR = crownR + ringW
            let off    = CGSize(width: state.renderedOffset.y, height: state.renderedOffset.x)
            let eq = proj.rings[1]

            ZStack {
                ForEach(proj.rings) { parallel in
                    ZStack {
                        Circle()
                            .fill(parallel.color.opacity(0.2))
                            .frame(
                                width: parallel.radius * 2,
                                height: parallel.radius * 2
                            )
                            .blur(radius: 1)
//                        Circle()
//                            .fill(.ultraThinMaterial)
//                            .frame(
//                                width: parallel.radius * 2,
//                                height: parallel.radius * 2
//                            )
                            
                    }
                    .offset(x: state.renderedOffset.y, y: state.renderedOffset.x + parallel.centerOffset)
                    .mask(
                        Circle()
                            .frame(width: 2 * crownR, height: 2 * crownR).offset(off)
                    )
                    
                }
            }
            
            Ring(
                radius: eq.radius,
                lineWidth: ringW,
                //                    tint: parallel.color
            )
            .offset(x: state.renderedOffset.y, y: state.renderedOffset.x + eq.centerOffset)
            .mask(
                Circle()
                    .frame(width: 2 * crownR, height: 2 * crownR).offset(off)
            )

            ZStack {
                GlassRing(radius: outerR + 6, lineWidth: ringW, tint: .clear)
                
            }
                .offset(off)
            

            ForEach(0..<24, id: \.self) { h in
                let angle  = -(-.pi / 2 - Double(h) * .pi / 12.0)
                let midR   = (crownR + ringW / 2) + 20
                let tz     = TimeZone.current.secondsFromGMT(for: state.observationDate) / 3600
                let label  = (h + tz + 24) % 24
                let hour   = Calendar.current.component(.hour, from: Date())
                let current = hour == label
                hourNumber(label.description, current ? .yellow : primaryColor)
                    .offset(
                        x: state.renderedOffset.y + cos(angle) * midR,
                        y: state.renderedOffset.x + sin(angle) * midR
                    )
            }
            
           
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func hourNumber(_ string: String, _ color: Color?) -> some View {
        Text(string)
            .font(.caption2.weight(.light))
            .fontDesign(.serif)
            .foregroundStyle(color ?? .white)
    }

    private var primaryColor: Color {
        cS == .dark ? .white : .black
    }
}

#Preview {
    WatchMaskView()
        .environment(EAppState())
}

// MARK: - SProjection

@Observable
public class SProjection: Identifiable {
    public typealias Pixel = Double

    public let id = UUID()
    public var baseLatitude:    Angle
    public var scale:           Pixel
    public var maxValue:        Pixel   = 9999
    public var parallelOffsets: [Angle] = []

    public init(baseLatitude: Angle, scale: Pixel = 100.0, parallelOffsets: [Angle] = []) {
        self.baseLatitude    = baseLatitude
        self.scale           = scale
        self.parallelOffsets = parallelOffsets
    }

    // Projected circle for a small circle (parallel) at angular distance `offset` from baseLatitude.
    // d1 uses the antioffset side (base - offset), d2 uses the offset side (base + offset).
    public func ring(at offset: Angle) -> ParallelRing? {
        let latAnti = baseLatitude.radians - offset.radians
        let latOff  = baseLatitude.radians + offset.radians

        let t1 = tan(latAnti / 2)
        guard abs(t1) > 1e-6 else { return nil }
        let d1 = min(scale / t1, maxValue)

        let t2 = tan(latOff / 2)
        guard abs(t2) > 1e-6 else { return nil }
        let d2 = -scale * t2

        return ParallelRing(
            radius:       min((d1 - d2) / 2, maxValue),
            centerOffset: min((d1 + d2) / 2, maxValue)
        )
    }

    // All projected circles for the stored parallelOffsets.
    public var rings: [ParallelRing] {
        parallelOffsets.enumerated().compactMap { i, offset in
            guard var r = ring(at: offset) else { return nil }
            r.id = i
            return r
        }
    }

    public struct ParallelRing: Identifiable {
        public var id:           Int   = 0
        public let radius:       Pixel
        public let centerOffset: Pixel
        
        public var color: Color {
            if id == 0 { return Color.sunGold }
            if id == 1 { return Color.mutedRose }
            if id == 2 { return Color.deepNavy }
            if id == 3 { return Color.darkIndigo }
            if id == 4 { return Color.nearBlack }
            else       { return Color.gray }
        }
    }
}
