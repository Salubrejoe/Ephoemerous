import SwiftUI

struct FilterView: View {
    @Binding var magnitudeCap: Double
    let magnitudeRange: ClosedRange<Double>
    let starCount: Int
    @Environment(EAppState.self) var state

    private struct LayerToggle {
        let label: String
        let symbol: String
        let binding: (EAppState) -> Binding<Bool>
    }

    var body: some View {
//        let bindable = Bindable(state)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Magnitude slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(Strings.Sort.brighterThan)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(String(format: Strings.Format.magnFormat, magnitudeCap))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(starCount) stars")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Slider(value: $magnitudeCap, in: magnitudeRange, step: 0.1)
                        .tint(.primary)
                }
            }
        }
    }
}



#Preview {
    FilterView(magnitudeCap: .constant(5.5), magnitudeRange: -2...8, starCount: 1234)
        .environment(EAppState())
}


/*
 
 Divider()
 // Layer toggles
 Text("Layers")
 .font(.subheadline.weight(.medium))
 LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
 ELayerToggle(label: "Equator",    symbol: "circle.dashed",         isOn: bindable.showEquatorTropics)
 ELayerToggle(label: "Ecliptic",   symbol: "sun.max",               isOn: bindable.showEcliptic)
 ELayerToggle(label: "NS Grid",    symbol: "map",                   isOn: bindable.showNSMeridians)
 ELayerToggle(label: "UL Grid",    symbol: "location.north.line",   isOn: bindable.showULMeridians)
 ELayerToggle(label: "Horizon",    symbol: "mountain.2",            isOn: bindable.showHorizon)
 ELayerToggle(label: "Stars",      symbol: "star",                  isOn: bindable.showStars)
 ELayerToggle(label: "Planets",    symbol: "globe",                 isOn: bindable.showPlanets)
 ELayerToggle(label: "Selection",  symbol: "sparkles",              isOn: bindable.showSelectedStars)
 }
 }
 .padding(24)
 
 
 // MARK: - Toggle chip
 private struct ELayerToggle: View {
 let label:  String
 let symbol: String
 @Binding var isOn: Bool
 
 var body: some View {
 Button { isOn.toggle() } label: {
 HStack(spacing: 6) {
 Image(systemName: symbol)
 .font(.caption)
 Text(label)
 .font(.caption.weight(.medium))
 Spacer()
 }
 .padding(.horizontal, 10)
 .padding(.vertical, 8)
 .background(isOn ? Color.primary.opacity(0.12) : Color.primary.opacity(0.04),
 in: RoundedRectangle(cornerRadius: 10, style: .continuous))
 .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
 .strokeBorder(isOn ? Color.primary.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: 0.5))
 .foregroundStyle(isOn ? .primary : .secondary)
 }
 .buttonStyle(.plain)
 }
 }
 */
