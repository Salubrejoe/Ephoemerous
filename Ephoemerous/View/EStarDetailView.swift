import SwiftUI

struct EStarDetailView: View {
    @Environment(EAppState.self) var state
    @Environment(\.dismiss) var dismiss
    let star: EStar

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {

                // Hero glow
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [star.spectralClass.color.opacity(0.4), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)

                    let r = max(12.0, min(36.0, (6.5 - star.magnitude) * 6.0))
                    Circle()
                        .fill(star.spectralClass.color)
                        .frame(width: r, height: r)
                        .shadow(color: star.spectralClass.color, radius: 12)
                }
                .padding(.top, 8)
                
                // Coordinates card
                EDetailCard(title: "Coordinates") {
                    EDetailRow(label: "Right Ascension", value: star.rightAscension.hmsString)
                    EDetailRow(label: "Declination",     value: star.declination.dmsString)
                }

                // Physical card
                EDetailCard(title: "Physical") {
                    if let dist = star.distanceLY {
                        EDetailRow(label: "Distance",
                                   value: String(format: "%.1f ly", dist))
                    }
                    EDetailRow(label: "Magnitude",      value: String(format: "%.2f", star.magnitude))
                    EDetailRow(label: "Spectral Class", value: star.spectralClass.rawValue)
                    EDetailRow(label: "Constellation",  value: star.constellation.fullName)
                    if star.properName != nil {
                        EDetailRow(label: "Bayer",      value: star.name)
                    }
                }

                // Proper motion card
                EDetailCard(title: "Proper Motion") {
                    EDetailRow(label: "RA  (mas/yr)", value: String(format: "%.3f", star.pmRA))
                    EDetailRow(label: "Dec (mas/yr)", value: String(format: "%.3f", star.pmDE))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle(star.displayName)
        .navigationBarTitleDisplayMode(.large)
        .background(.black)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    state.selectedStar = star
                    dismiss()
                } label: {
                    Image(systemName: "target")
                        .frame(height: 55)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Card & Row helpers

private struct EDetailCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                content()
            }
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        Divider().opacity(0.3).padding(.horizontal, 16)
    }
}

// MARK: - Angle helpers

private extension Angle {
    var hmsString: String {
        let totalSec = radians * (12.0 / Double.pi) * 3600
        let h = Int(totalSec / 3600)
        let m = Int(totalSec.truncatingRemainder(dividingBy: 3600) / 60)
        let s = totalSec.truncatingRemainder(dividingBy: 60)
        return String(format: "%02dh %02dm %05.2fs", h, m, s)
    }
    var dmsString: String {
        let deg = degrees
        let sign = deg >= 0 ? "+" : "-"
        let abs  = Swift.abs(deg)
        let d = Int(abs)
        let m = Int((abs - Double(d)) * 60)
        let s = (abs - Double(d) - Double(m)/60) * 3600
        return String(format: "%@%02d\u{00b0} %02d\u{2019} %05.2f\u{201d}", sign, d, m, s)
    }
}

#Preview {
    NavigationStack {
        EStarDetailView(star: EStar.mockStars[0])
    }
    .preferredColorScheme(.dark)
}
