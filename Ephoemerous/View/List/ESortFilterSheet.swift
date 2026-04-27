
import SwiftUI


struct ESortFilterSheet: View {
    @Binding var sortOrder: EStarSort; @Binding var magnitudeCap: Double
    let magnitudeRange: ClosedRange<Double>; let starCount: Int
    var body: some View {
        NavigationStack {
            List {
                Section(Strings.Sort.sortBy) {
                    ForEach(EStarSort.allCases) { option in
                        HStack { Text(option.rawValue); Spacer(); if sortOrder == option { Image(symbol: .checkmark) } }
                            .contentShape(Rectangle()).onTapGesture { sortOrder = option }.listRowBackground(Color.white.opacity(0.05))
                    }
                }
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text(Strings.Sort.brighterThan); Spacer(); Text(String(format: Strings.Format.magnFormat, magnitudeCap)).monospacedDigit().foregroundStyle(.secondary) }
                        Slider(value: $magnitudeCap, in: magnitudeRange, step: 0.5).tint(.blue)
                    }.padding(.vertical, 4).listRowBackground(Color.white.opacity(0.05))
                } header: { Text(Strings.Titles.magnFilter.rawValue) }
                footer: { Text("\(starCount) stars shown").foregroundStyle(.secondary) }
            }
            .scrollContentBackground(.hidden).navigationTitle(Strings.Titles.sortNFilter.rawValue).navigationBarTitleDisplayMode(.inline)
        }
    }
}
