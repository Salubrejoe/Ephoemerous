import SwiftUI

// MARK: - EPalettePreview
// Visual sandbox for every colour in `EPalette`. Sections mirror the
// palette's own grouping so you can scroll the list and see every
// hex value alongside its semantic name. Edit `EPalette.swift`,
// re-open this preview — the swatches update.
struct EPalettePreview: View {

    private let palette = EArtist.shared.palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    surfaces
                    gridAndAxes
                    horizon
                    constellationsBasics
                    mythGradients
                    solarSystem
                    userPuck
                    spectral
                }
                .padding(.horizontal, 16)
                .padding(.vertical,   20)
            }
            .background(palette.canvasBackground)
            .navigationTitle("EPalette")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Sections

    private var surfaces: some View {
        section("Surfaces") {
            swatchGrid {
                solidSwatch("canvasBackground", palette.canvasBackground)
            }
        }
    }

    private var gridAndAxes: some View {
        section("Grid & axes") {
            swatchGrid {
                solidSwatch("grid",     palette.grid)
                solidSwatch("ecliptic", palette.ecliptic)
            }
        }
    }

    private var horizon: some View {
        section("Horizon") {
            swatchGrid {
                solidSwatch("horizonFill",  palette.horizonFill)
                solidSwatch("twilightBand", palette.twilightBand)
            }
        }
    }

    private var constellationsBasics: some View {
        section("Constellation lines + placeholder") {
            swatchGrid {
                solidSwatch("constellationLine",
                            palette.constellationLine)
                solidSwatch("constellationPlaceholderFill",
                            palette.constellationPlaceholderFill)
            }
        }
    }

    private var mythGradients: some View {
        section("Constellation myth gradients") {
            gradientGrid {
                gradientSwatch("perseus",              palette.perseus)
                gradientSwatch("hercules",             palette.hercules)
                gradientSwatch("argo",                 palette.argo)
                gradientSwatch("zeus",                 palette.zeus)
                gradientSwatch("orion",                palette.orion)
                gradientSwatch("orpheus",              palette.orpheus)
                gradientSwatch("mythNone",             palette.mythNone)
                gradientSwatch("mythForeverInvisible", palette.mythForeverInvisible)
            }
        }
    }

    private var solarSystem: some View {
        section("Solar system gradients") {
            gradientGrid {
                gradientSwatch("sun",     palette.sun)
                gradientSwatch("moon",    palette.moon)
                gradientSwatch("mercury", palette.mercury)
                gradientSwatch("venus",   palette.venus)
                gradientSwatch("mars",    palette.mars)
                gradientSwatch("jupiter", palette.jupiter)
                gradientSwatch("saturn",  palette.saturn)
                gradientSwatch("uranus",  palette.uranus)
                gradientSwatch("neptune", palette.neptune)
            }
        }
    }

    private var userPuck: some View {
        section("User-location puck") {
            swatchGrid {
                solidSwatch("userPuckDisc", palette.userPuckDisc)
                solidSwatch("userPuckRing", palette.userPuckRing)
                solidSwatch("userPuckCone", palette.userPuckCone)
            }
        }
    }

    /// Spectral classes — dark and light variants side by side so the
    /// pairing is obvious. Each row is one class: O, B, A, F, G, K, M,
    /// unknown.
    private var spectral: some View {
        section("Spectral classes (dark / light)") {
            VStack(spacing: 8) {
                ForEach(EHRClass.allCases, id: \.self) { cls in
                    HStack(spacing: 12) {
                        Text(cls.rawValue.uppercased())
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .leading)
                        swatchRect(palette.spectralDark(cls))
                            .overlay(spectralOverlay("dark"))
                        swatchRect(palette.spectralLight(cls))
                            .overlay(spectralOverlay("light"))
                    }
                    .frame(height: 36)
                }
            }
        }
    }

    private func spectralOverlay(_ label: String) -> some View {
        Text(label)
            .font(.caption2)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical,   2)
            .background(.black.opacity(0.35), in: Capsule())
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: .topLeading)
    }

    // MARK: Section primitive

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content)
        -> some View
    {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            content()
        }
    }

    // MARK: Swatch grids

    /// Square swatch grid for solid colours. Three columns at iPhone
    /// width, more on iPad-ish widths via `.adaptive`.
    private func swatchGrid<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        LazyVGrid(
            columns: Array(repeating: .init(.flexible(), spacing: 12),
                           count: 2),
            spacing: 12
        ) {
            content()
        }
    }

    /// Wider grid for gradients (2:1 aspect so the top → bottom ramp
    /// is visible).
    private func gradientGrid<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        LazyVGrid(
            columns: Array(repeating: .init(.flexible(), spacing: 12),
                           count: 2),
            spacing: 12
        ) {
            content()
        }
    }

    // MARK: Individual swatches

    private func solidSwatch(_ name: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            swatchRect(color).frame(height: 64)
            Text(name)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func gradientSwatch(_ name: String,
                                _ gradient: EPalette.Gradient) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(
                    colors: [gradient.top, gradient.bottom],
                    startPoint: .top,
                    endPoint:   .bottom))
                .frame(height: 64)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
            Text(name)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func swatchRect(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(color)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
    }
}

// MARK: - Previews

#Preview("EPalette — light") {
    EPalettePreview()
        .preferredColorScheme(.light)
}

#Preview("EPalette — dark") {
    EPalettePreview()
        .preferredColorScheme(.dark)
}
