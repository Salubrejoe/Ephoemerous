import SwiftUI

// MARK: - EPaletteVariantsPreview
// Side-by-side study of the three palette candidates: the current
// production `EPalette` (labelled "Classic" here), `EPalette2`
// (Vivid), and `EPalette3` (Pastel). Each column carries the same
// rows so the eye can scan across and compare a single semantic
// slot — perseus's myth gradient, mars's planet gradient, the
// spectral M class — across all three styles at once.
//
// Not wired into the app. To pick a winner: scroll, then commit
// the chosen palette's values back into `EPalette` (or refactor
// `EPalette` into a protocol and switch the conformer).

struct EPaletteVariantsPreview: View {

    private let classic = EArtist.shared.palette
    private let vivid   = EPalette2()
    private let pastel  = EPalette3()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    columnHeaders
                    surfacesRow
                    horizonRow
                    constellationRow
                    mythRows
                    solarRows
                    puckRow
                    spectralRows
                }
                .padding(.horizontal, 16)
                .padding(.vertical,   20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Palette variants")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Column headers

    private var columnHeaders: some View {
        HStack(spacing: 8) {
            Spacer().frame(width: rowLabelWidth)
            header("Classic")
            header("Vivid")
            header("Pastel")
        }
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Rows

    private var surfacesRow: some View {
        row("Background") {
            HStack(spacing: 8) {
                solid(classic.canvasBackground)
                solid(vivid  .canvasBackground)
                solid(pastel .canvasBackground)
            }
        }
    }

    private var horizonRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Horizon fill") {
                HStack(spacing: 8) {
                    solid(classic.horizonFill)
                    solid(vivid  .horizonFill)
                    solid(pastel .horizonFill)
                }
            }
            row("Twilight band") {
                HStack(spacing: 8) {
                    solid(classic.twilightBand)
                    solid(vivid  .twilightBand)
                    solid(pastel .twilightBand)
                }
            }
        }
    }

    private var constellationRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Const. line") {
                HStack(spacing: 8) {
                    solid(classic.constellationLine)
                    solid(vivid  .constellationLine)
                    solid(pastel .constellationLine)
                }
            }
            row("Ecliptic") {
                HStack(spacing: 8) {
                    solid(classic.ecliptic)
                    solid(vivid  .ecliptic)
                    solid(pastel .ecliptic)
                }
            }
        }
    }

    private var mythRows: some View {
        section("Myth gradients") {
            VStack(spacing: 6) {
                mythRow("Perseus",  classic.perseus,  vivid.perseus,  pastel.perseus)
                mythRow("Hercules", classic.hercules, vivid.hercules, pastel.hercules)
                mythRow("Argo",     classic.argo,     vivid.argo,     pastel.argo)
                mythRow("Zeus",     classic.zeus,     vivid.zeus,     pastel.zeus)
                mythRow("Orion",    classic.orion,    vivid.orion,    pastel.orion)
                mythRow("Orpheus",  classic.orpheus,  vivid.orpheus,  pastel.orpheus)
            }
        }
    }

    private func mythRow(_ label: String,
                         _ a: EPalette.Gradient,
                         _ b: EPalette2.Gradient,
                         _ c: EPalette3.Gradient) -> some View {
        row(label) {
            HStack(spacing: 8) {
                gradient(a)
                gradient(b)
                gradient(c)
            }
        }
    }

    private var solarRows: some View {
        section("Solar system") {
            VStack(spacing: 6) {
                solarRow("Sun",     classic.sun,     vivid.sun,     pastel.sun)
                solarRow("Moon",    classic.moon,    vivid.moon,    pastel.moon)
                solarRow("Mercury", classic.mercury, vivid.mercury, pastel.mercury)
                solarRow("Venus",   classic.venus,   vivid.venus,   pastel.venus)
                solarRow("Mars",    classic.mars,    vivid.mars,    pastel.mars)
                solarRow("Jupiter", classic.jupiter, vivid.jupiter, pastel.jupiter)
                solarRow("Saturn",  classic.saturn,  vivid.saturn,  pastel.saturn)
                solarRow("Uranus",  classic.uranus,  vivid.uranus,  pastel.uranus)
                solarRow("Neptune", classic.neptune, vivid.neptune, pastel.neptune)
            }
        }
    }

    private func solarRow(_ label: String,
                          _ a: EPalette.Gradient,
                          _ b: EPalette2.Gradient,
                          _ c: EPalette3.Gradient) -> some View {
        row(label) {
            HStack(spacing: 8) {
                gradient(a)
                gradient(b)
                gradient(c)
            }
        }
    }

    private var puckRow: some View {
        section("User puck") {
            row("Disc") {
                HStack(spacing: 8) {
                    solid(classic.userPuckDisc)
                    solid(vivid  .userPuckDisc)
                    solid(pastel .userPuckDisc)
                }
            }
        }
    }

    private var spectralRows: some View {
        section("Spectral (dark mode)") {
            VStack(spacing: 6) {
                spectralRow("O", classic.spectralODark, vivid.spectralODark, pastel.spectralODark)
                spectralRow("B", classic.spectralBDark, vivid.spectralBDark, pastel.spectralBDark)
                spectralRow("A", classic.spectralADark, vivid.spectralADark, pastel.spectralADark)
                spectralRow("F", classic.spectralFDark, vivid.spectralFDark, pastel.spectralFDark)
                spectralRow("G", classic.spectralGDark, vivid.spectralGDark, pastel.spectralGDark)
                spectralRow("K", classic.spectralKDark, vivid.spectralKDark, pastel.spectralKDark)
                spectralRow("M", classic.spectralMDark, vivid.spectralMDark, pastel.spectralMDark)
            }
        }
    }

    private func spectralRow(_ label: String, _ a: Color, _ b: Color, _ c: Color) -> some View {
        row(label) {
            HStack(spacing: 8) {
                solid(a)
                solid(b)
                solid(c)
            }
        }
    }

    // MARK: - Building blocks

    private let rowLabelWidth: CGFloat = 100
    private let swatchHeight:  CGFloat = 36

    @ViewBuilder
    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
                .padding(.top, 8)
            content()
        }
    }

    @ViewBuilder
    private func row<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary)
                .frame(width: rowLabelWidth, alignment: .leading)
            content()
        }
    }

    private func solid(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color)
            .frame(maxWidth: .infinity)
            .frame(height: swatchHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
            )
    }

    private func gradient<G>(_ g: G) -> some View where G == (top: Color, bottom: Color) {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(LinearGradient(colors: [g.top, g.bottom],
                                 startPoint: .top,
                                 endPoint:   .bottom))
            .frame(maxWidth: .infinity)
            .frame(height: swatchHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
            )
    }
}

// MARK: - Previews

#Preview("All three") {
    EPaletteVariantsPreview()
}

#Preview("Vivid — on canvas bg") {
    let p = EPalette2()
    return ScrollView {
        VStack(spacing: 12) {
            sampleBadges(
                myth: (p.perseus,  p.hercules, p.argo,
                       p.zeus,     p.orion,    p.orpheus),
                puck: p.userPuckDisc
            )
        }
        .padding(24)
    }
    .background(p.canvasBackground)
}

#Preview("Pastel — on canvas bg") {
    let p = EPalette3()
    return ScrollView {
        VStack(spacing: 12) {
            sampleBadges(
                myth: (p.perseus,  p.hercules, p.argo,
                       p.zeus,     p.orion,    p.orpheus),
                puck: p.userPuckDisc
            )
        }
        .padding(24)
    }
    .background(p.canvasBackground)
}

/// Helper for the on-canvas previews — renders six myth-gradient
/// badges plus a puck disc as if they were sitting on the chart, so
/// you can read the foreground/background contrast directly.
@ViewBuilder
private func sampleBadges(
    myth: (perseus:  (top: Color, bottom: Color),
           hercules: (top: Color, bottom: Color),
           argo:     (top: Color, bottom: Color),
           zeus:     (top: Color, bottom: Color),
           orion:    (top: Color, bottom: Color),
           orpheus:  (top: Color, bottom: Color)),
    puck: Color
) -> some View {
    let labels = ["Perseus", "Hercules", "Argo",
                  "Zeus",    "Orion",    "Orpheus"]
    let grads  = [myth.perseus,  myth.hercules, myth.argo,
                  myth.zeus,     myth.orion,    myth.orpheus]
    VStack(spacing: 12) {
        ForEach(Array(zip(labels, grads).enumerated()), id: \.offset) { _, pair in
            HStack(spacing: 12) {
                Circle()
                    .fill(LinearGradient(colors: [pair.1.top, pair.1.bottom],
                                         startPoint: .top,
                                         endPoint:   .bottom))
                    .frame(width: 36, height: 36)
                Text(pair.0)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
        }
        HStack(spacing: 12) {
            Circle()
                .fill(puck)
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .frame(width: 36, height: 36)
            Text("You are here")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}
