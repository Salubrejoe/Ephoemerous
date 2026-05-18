import SwiftUI

// Test harness: composes every astrolabe layer back → front and drives
// latitude / date / time from @State sliders. Location & date are
// hardcoded to Prague-ish defaults for now.
struct OrlojView: View {

    @State private var latitudeDeg: Double = 50.0   // φ
    @State private var dayOfYear:   Double = 80.0   // ~vernal equinox
    @State private var hour:        Double = 12.0   // UT hours

    private let pragueLongitude = Angle.degrees(14.42)

    private var date: Date {
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 1
        c.timeZone = TimeZone(identifier: "UTC")
        let base = Calendar(identifier: .gregorian).date(from: c)!
        return base.addingTimeInterval(dayOfYear * 86_400 + hour * 3_600)
    }

    private func geometry(in size: CGSize) -> EOrlojGeometry {
        let half = min(size.width, size.height) / 2
        // Clamp φ away from 0 and the poles — the projection degenerates there.
        let phi = max(3, min(65, abs(latitudeDeg))) * (latitudeDeg < 0 ? -1 : 1)
        return EOrlojGeometry(
            latitude:   .degrees(phi),
            obliquity:  AstroConstants.obliquity,
            date:       date,
            longitude:  pragueLongitude,
            unitRadius: half * 0.50,
            center:     CGPoint(x: size.width / 2, y: size.height / 2)
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { geo in
                let g = geometry(in: geo.size)
                ZStack {
                    OrlojPlateLayer(geometry: g)
                    OrlojHorizonLayer(geometry: g)
                    OrlojUnequalHoursLayer(geometry: g)
                    OrlojRomanDialLayer(geometry: g)
                    OrlojBohemianRingLayer(geometry: g)
                    OrlojZodiacLayer(geometry: g)
                    OrlojSunHandLayer(geometry: g)
                    OrlojMoonHandLayer(geometry: g)
                }
                
            }
            .aspectRatio(1, contentMode: .fit)

            VStack(spacing: 10) {
                sliderRow("Latitude φ",
                          value: $latitudeDeg, range: -65...65,
                          text: String(format: "%.1f°", latitudeDeg))
                sliderRow("Day of year",
                          value: $dayOfYear, range: 0...365,
                          text: String(format: "%.0f", dayOfYear))
                sliderRow("Hour (UT)",
                          value: $hour, range: 0...24,
                          text: String(format: "%.1f h", hour))
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private func sliderRow(_ label: String,
                           value: Binding<Double>,
                           range: ClosedRange<Double>,
                           text: String) -> some View {
        HStack {
            Text(label).frame(width: 110, alignment: .leading)
            Slider(value: value, in: range)
            Text(text).frame(width: 60, alignment: .trailing)
                .monospacedDigit()
        }
        .font(.caption)
    }
}

#Preview {
    OrlojView()
}
