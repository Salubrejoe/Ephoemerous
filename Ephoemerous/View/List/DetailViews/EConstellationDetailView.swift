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
                // ── Notable stars ─────────────────────────────────────────
                Section {
                    if !stars.isEmpty {
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
//            .padding(.horizontal)
        
        .navigationTitle(constellation.fullName)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            state.currentlyDisplayedConstellation = constellation
            if let brightest = brightestStar {
                state.applyStarTracking(brightest)
            }
        }
        .onDisappear {
            state.currentlyDisplayedConstellation = nil
        }
        .navigationDestination(for: EStar.self)  { s in EStarDetailView(star: s).onAppear { state.recordViewed(s) }
        }
    }
    
    var brightestStar: EStar? {
        stars.first
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

//                if constellation.isZodiacSign {
//                    Text(Strings.ConstellationDetail.zodiac)
//                        .font(.caption2.weight(.semibold))
//                        .foregroundStyle(.yellow.opacity(0.8))
//                        .padding(.horizontal, 10)
//                        .padding(.vertical, 3)
//                        .background(Capsule().fill(.yellow.opacity(0.15)))
//                        .overlay(Capsule().strokeBorder(.yellow.opacity(0.3), lineWidth: 0.5))
//                }
            }
        }
    }
}

// MARK: - Star row inside constellation detail

private struct EConstellationStarRow: View {
    let star: EStar

    var body: some View {
        HStack(spacing: 12) {
            SelectStarButton(star: star)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(star.displayName).font(.body.weight(.semibold))
                Text("@\(star.constellation.fullName)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f mag", star.magnitude)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
    }
}
