import SwiftUI

// MARK: - DetailStat / DetailStatList
// A plain vertical label → value list for the detail sheets, replacing the
// horizontal fact-card scroll (`DetailHScrollView`). The cards could only
// show the three or four facts that fit across the sheet; this shows ALL
// the data a body carries, one row each, and scrolls when the sheet is
// dragged up.
struct DetailStat: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

struct DetailStatList: View {
    let stats: [DetailStat]

    var body: some View {
        List(stats) { stat in
            LabeledContent {
                Text(stat.value)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
            } label: {
                Text(stat.label)
                    .foregroundStyle(.primary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    DetailStatList(stats: [
        .init(label: "Constellation",   value: "Orion"),
        .init(label: "Spectral class",  value: "M1-2"),
        .init(label: "Magnitude",       value: "0.5"),
        .init(label: "Distance",        value: "548 ly"),
        .init(label: "Right ascension", value: "5h 55m"),
        .init(label: "Declination",     value: "+7.4°"),
    ])
}
