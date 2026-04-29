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
        ScrollView {
            VStack(spacing: 32) {
                
                
                // ── Info ──────────────────────────────────────────────────
                ENSBodyCard(title: Strings.ConstellationDetail.identity) {
                    ENSBodyRow(label: Strings.ConstellationDetail.abbreviation, value: constellation.rawValue)
                    ENSBodyRow(label: Strings.ConstellationDetail.fullName,    value: constellation.fullName)
                    if constellation.isZodiacSign {
                        ENSBodyRow(label: Strings.ConstellationDetail.zodiac,   value: "Yes")
                    }
                }
                
                // ── Notable stars ─────────────────────────────────────────
                if !stars.isEmpty {
                    ENSBodyCard(title: "Stars  (\(stars.count))") {
                        ForEach(stars.prefix(12)) { star in
                            NavigationLink(value: star) {
                                EConstellationStarRow(star: star)
                            }
                        }
                        if stars.count > 12 {
                            ENSBodyRow(label: "…and \(stars.count - 12) more", value: "")
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle(constellation.fullName)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: EStar.self)  { s in EStarDetailView(star: s).onAppear { state.recordViewed(s) }
        }
    }
}

// MARK: - Hero

private struct EConstellationHero: View {
    let constellation: EConstellation

    var body: some View {
        ZStack {
            // Soft starfield gradient
            Circle()
                .fill(RadialGradient(
                    colors: [.white.opacity(0.08), .clear],
                    center: .center, startRadius: 0, endRadius: 90))
                .frame(width: 180, height: 180)

            VStack(spacing: 8) {
                Text(constellation.rawValue)
                    .font(.system(size: 52, weight: .thin, design: .serif))
                    .foregroundStyle(.white)

                if constellation.isZodiacSign {
                    Text(Strings.ConstellationDetail.zodiac)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.yellow.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.yellow.opacity(0.15)))
                        .overlay(Capsule().strokeBorder(.yellow.opacity(0.3), lineWidth: 0.5))
                }
            }
        }
    }
}

// MARK: - Star row inside constellation detail

private struct EConstellationStarRow: View {
    let star: EStar

    var body: some View {
        HStack(spacing: 12) {
            let r = max(4.0, min(12.0, (AstroConstants.listDotScale - star.magnitude) * AstroConstants.listDotFactor))
            Circle()
                .fill(star.spectralClass.color)
                .frame(width: r, height: r)

            Text(star.displayName)
                .font(.headline.monospacedDigit())
//                .foregroundStyle(.primary)

            Spacer()

            Text(String(format: "%.2f mag", star.magnitude))
                .font(.headline.monospacedDigit())
//                .foregroundStyle(.primary)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        Divider().opacity(0.3).padding(.horizontal, 16)
    }
}
