import SwiftUI

// MARK: - EStarDetailView

struct EStarDetailView: View {
    @Environment(EAppState.self) var state
    @Environment(\.dismiss) var dismiss
    let star: EStar

    private var accent: Color { star.spectralClass.color }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                EDetailSubtitle(text: star.name + " - " + star.constellation.fullName)
                spectralSection
                Divider().padding(.bottom, 24)
                distanceSection
                Divider().padding(.bottom, 24)
                magnitudeSection
                Divider().padding(.bottom, 24)
                coordinatesSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(star.displayName)
        .navigationBarTitleDisplayMode(.large)
        .background(glowBackground())
        .toolbar {
            ToolbarItem(placement: .automatic) {
                FavouriteButton(star: star)
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }

    private var spectralSection: some View {
        Group {
            EDetailSectionLabel(text: "Spectral class")
            SpectralClassRow(spectralClass: star.spectralClass)
                .padding(.bottom, 28)
        }
    }

    private var distanceSection: some View {
        Group {
            EDetailSectionLabel(text: "Distance")
            DistanceHero(distanceLY: star.distanceLY)
                .padding(.bottom, 28)
        }
    }

    private var magnitudeSection: some View {
        Group {
            EDetailSectionLabel(text: "Apparent magnitude")
            MagnitudeRow(magnitude: star.magnitude, accent: accent)
                .padding(.bottom, 28)
        }
    }

    private var coordinatesSection: some View {
        Group {
            EDetailSectionLabel(text: "Equatorial coordinates")
            ECoordinateDials(ra: star.rightAscension, dec: star.declination, accent: accent)
        }
    }

    @ViewBuilder
    private func glowBackground() -> some View {
        ZStack {
            Circle()
                .fill(state.isFavouriteStar(star) ? star.spectralClass.color : .clear)
                .frame(width: 33, height: 33)
                .blur(radius: 30)
                .padding(25)
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}

// MARK: - Spectral class row

private struct SpectralClassRow: View {
    let spectralClass: EHRClass
    private let sequence: [EHRClass] = [.O, .B, .A, .F, .G, .K, .M]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(sequence, id: \.self) { cls in
                    ZStack {
                        Circle()
                            .fill(cls == spectralClass ? cls.color : Color.primary.opacity(0.06))
                            .frame(width: 32, height: 32)
                        Text(cls.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(cls == spectralClass ? .black.opacity(0.7) : .secondary)
                    }
                }
            }
            HStack {
                Text("hotter - bluer")
                Spacer()
                Text("cooler - redder")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Magnitude row

private struct MagnitudeRow: View {
    let magnitude: Double
    let accent: Color

    private let brightest = -1.46
    private let faintest  =  6.5

    private var scaleFraction: Double {
        ((magnitude - brightest) / (faintest - brightest)).clamped(to: 0...1)
    }

    private var eyeLabel: String {
        switch magnitude {
        case ..<(-1):  return "brilliant"
        case ..<0:     return "very bright"
        case ..<2:     return "naked eye"
        case ..<4:     return "easily visible"
        case ..<6:     return "dark sky"
        default:       return "limit"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%.2f", magnitude))
                    .font(.largeTitle)
                    .fontWeight(.medium)
                    .fontDesign(.serif)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(eyeLabel)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 3)
                    Capsule()
                        .fill(accent.opacity(0.5))
                        .frame(width: geo.size.width * scaleFraction, height: 3)
                    Circle()
                        .fill(accent)
                        .frame(width: 8, height: 8)
                        .offset(x: max(0, geo.size.width * scaleFraction - 4))
                }
            }
            .frame(height: 8)
            HStack {
                Text("brighter")
                Spacer()
                Text("fainter +6.5")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Distance hero

private struct DistanceHero: View {
    let distanceLY: Double?

    private var parsecs: Double? { distanceLY.map { $0 / 3.26156 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let ly = distanceLY {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(ly < 100 ? String(format: "%.1f", ly) : String(format: "%.0f", ly))
                        .font(.largeTitle)
                        .fontWeight(.medium)
                        .fontDesign(.serif)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("ly")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fontDesign(.serif)
                }
                if let pc = parsecs {
                    Text(String(format: "~%.0f pc", pc))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                        .fontDesign(.serif)
                }
            } else {
                Text("Unknown")
                    .font(.largeTitle)
                    .fontWeight(.medium)
                    .fontDesign(.serif)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Clamp helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EStarDetailView(star: EStar.mockStars[0])
    }
    .environment(EAppState())
}
