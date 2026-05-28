import SwiftUI

struct EConstellationDetailView: View {
    @Environment(EAppState.self) var state
    let constellation: EConstellation

    private var stars: [EStar] {
        StarDatabase.shared.workableStars
            .filter { $0.constellation == constellation && $0.name != "Unknown" }
            .sorted { $0.magnitude < $1.magnitude }
    }

    var body: some View {
        List {
            Section {
                if !stars.isEmpty {
                    ForEach(stars.prefix(12)) { star in
                        NavigationLink(value: star) {
                            EConstellationStarRow(star: star)
                        }
                        .padding(.leading, 33)
                        .overlay {
                            FavouriteButton(star: star)
                                .scaleEffect(0.6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if stars.count > 12 {
                        Text("...and \(stars.count - 12) more")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .navigationTitle(constellation.fullName)
        .navigationBarTitleDisplayMode(.large)
        // No side effects on the sky from this view itself — no
        // auto-tracking the brightest star, no border selection — it
        // just renders the constellation's roster. The opening flow
        // (which sets `detailDestination` and pans the canvas) lives
        // in `EAppState.focus(on:)`.
        .navigationDestination(for: EStar.self) { s in
            EStarDetailView(star: s).onAppear { state.recordViewed(s) }
        }
    }
}

// MARK: - Star row

private struct EConstellationStarRow: View {
    let star: EStar

    var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(star.displayName)
                    .font(.body)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f mag", star.magnitude))
                        .font(.caption)
                        .monospacedDigit()
                        .fontDesign(.serif)
                        .foregroundStyle(.secondary)
                }
            }
        
    }
}
