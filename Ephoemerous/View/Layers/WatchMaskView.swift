import SwiftUI

struct Ring: View {
    let radius     : Double
    let lineWidth  : Double

    var body: some View {
        Circle()
            .frame(width: 2 * radius, height: 2 * radius)
            .glassEffect()
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

    @State private var proj = SProjection(
        baseLatitude: .degrees(51),
        scale: 100,
        parallelOffsets: [.radians(0.1), .radians(0.0), .radians(-0.1), .radians(-0.2), .radians(-0.31)]
    )

    var body: some View {
        ZStack {
            let crownR = state.renderedScale * ENSWatchCrownLayer.clipRadius
            let ringW  = 4.0
            let outerR = crownR + ringW
            let off    = CGSize(width: state.renderedOffset.y, height: state.renderedOffset.x)

            ForEach(proj.rings) { parallel in
                Ring(radius: parallel.radius, lineWidth: ringW)
                    .offset(x: state.renderedOffset.y, y: state.renderedOffset.x + parallel.centerOffset)
                    .mask(
                        Circle().frame(width: 2 * crownR, height: 2 * crownR).offset(off)
                    )
            }

            Ring(radius: outerR, lineWidth: ringW)
                .offset(off)

            ForEach(0..<24, id: \.self) { h in
                let angle  = -(-.pi / 2 - Double(h) * .pi / 12.0)
                let midR   = (crownR + ringW / 2) + 24
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
        .onAppear {
            proj.baseLatitude = state.origin.latitude
            proj.scale        = 2 * state.scale
        }
        .onChange(of: state.origin.latitude) { _, newValue in
            proj.baseLatitude = newValue
        }
        .onChange(of: state.scale) { _, newValue in
            proj.scale = 2 * newValue
        }
    }

    @ViewBuilder
    private func hourNumber(_ string: String, _ color: Color?) -> some View {
        Text(string)
            .font(.subheadline.weight(.semibold))
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

    // Projected circle for one parallel at `offset` from baseLatitude.
    public func ring(at offset: Angle) -> ParallelRing? {
        let lat = baseLatitude.radians + offset.radians
        let t   = tan(lat / 2)
        guard abs(t) > 1e-6 else { return nil }
        let d1 = min(scale / t,  maxValue)
        let d2 = -scale * t
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
    }
}
