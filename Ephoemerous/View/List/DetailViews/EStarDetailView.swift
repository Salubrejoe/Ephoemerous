import SwiftUI

struct EStarDetailView: View {
    @Environment(EAppState.self) var state
    @Environment(\.dismiss) var dismiss
    let star: EStar

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {

                // ── Spectral header ───────────────────────────────────────
                EStarHeader(star: star)
                    .padding(.top, 8)

                // ── Coordinates ───────────────────────────────────────────
                EDetailCard(title: "Coordinates") {
                    EDetailRow(label: "Right Ascension", value: star.rightAscension.hmsString)
                    EDetailRow(label: "Declination",     value: star.declination.dmsString)
                }

                // ── Physical ──────────────────────────────────────────────
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

                // ── Proper Motion ─────────────────────────────────────────
                EDetailCard(title: "Proper Motion") {
                    EDetailRow(label: "RA  (mas/yr)", value: String(format: "%.3f", star.pmRA))
                    EDetailRow(label: "Dec (mas/yr)", value: String(format: "%.3f", star.pmDE))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle(star.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .background(background())
        
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    if state.selectedStars.contains(star) {
                        state.selectedStars.removeAll { $0.id == star.id }
                    } else {
                        state.selectedStars.append(star)
                    }
                } label: {
                    ZStack {
                        Image(symbol: state.selectedStars.contains(star) ? .target : .circle)
                            .shadow(
                                color: state.selectedStars.contains(star) ? star.spectralClass.color : .clear,
                                radius: 5
                            )
                    }
                }
                .foregroundStyle(color)
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }
    
    var color: Color {
        if state.selectedStars.contains(star) {
            star.spectralClass.color
        } else {
            star.spectralClass.color.opacity(0.2)
        }
    }
    
    @ViewBuilder
    private func background() -> some View {
        ZStack {
            Circle()
                .fill(state.selectedStars.contains(star) ? star.spectralClass.color : .clear)
                .frame(width: 50, height: 50)
                .blur(radius: 30)
                .padding(25)
        }
        .ignoresSafeArea()
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topTrailing
        )
    }
}

// MARK: - Spectral header

private struct EStarHeader: View {
    @Environment(EAppState.self) var state
    let star: EStar
    
    var color: Color {
        if state.selectedStars.contains(star) {
            star.spectralClass.color
        } else {
            star.spectralClass.color.opacity(0.2)
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // Gradient colour bar
            ZStack(alignment: .center) {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [
                            color.opacity(0.5),
                            color.opacity(0.15),
                            .clear
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    ))
                    .frame(height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(alignment: .bottom, spacing: 12) {
                    // Magnitude dot
                    let r = max(10.0, min(28.0, (6.5 - star.magnitude) * 4.5))
                    ZStack {
                        Circle()
                            .fill(RadialGradient(
                                colors: [.white, star.spectralClass.color],
                                center: .center,
                                startRadius: 0,
                                endRadius: r))
                            .frame(width: r, height: r)
                            .shadow(color: star.spectralClass.color, radius: 8)
                        Circle()
                            .strokeBorder(.white.opacity(0.4), lineWidth: 0.5)
                            .frame(width: r, height: r)
                    }
                    .padding(.leading, 16)
                    .padding(.bottom, 14)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(star.constellation.fullName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        Text(star.properName != nil ? star.name : "")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .padding(.bottom, 12)

                    Spacer()

                    // Spectral class chip
                    Text(star.spectralClass.rawValue)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(star.spectralClass.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(.black.opacity(0.4))
                                .overlay(Capsule()
                                    .strokeBorder(star.spectralClass.color.opacity(0.6),
                                                  lineWidth: 0.5))
                        )
                        .padding(.trailing, 16)
                        .padding(.bottom, 14)
                }
            }

            // Magnitude label strip
            HStack {
                Text(String(format: "mag %.2f", star.magnitude))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                if let d = star.distanceLY {
                    Text(String(format: "%.0f ly", d))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
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
//    var hmsString: String {
//        let totalSec = radians * (12.0 / Double.pi) * 3600
//        let h = Int(totalSec / 3600)
//        let m = Int(totalSec.truncatingRemainder(dividingBy: 3600) / 60)
//        let s = totalSec.truncatingRemainder(dividingBy: 60)
//        return String(format: "%02dh %02dm %05.2fs", h, m, s)
//    }
//    var dmsString: String {
//        let deg = degrees
//        let sign = deg >= 0 ? "+" : "-"
//        let a = Swift.abs(deg)
//        let d = Int(a)
//        let m = Int((a - Double(d)) * 60)
//        let s = (a - Double(d) - Double(m) / 60) * 3600
//        return String(format: "%@%02d\u{00b0} %02d\u{2019} %05.2f\u{201d}", sign, d, m, s)
//    }
}

#Preview {
    NavigationStack {
        EStarDetailView(star: EStar.mockStars[0])
    }
    .environment(EAppState())
    .preferredColorScheme(.dark)
}
