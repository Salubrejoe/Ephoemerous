#if DEBUG
import SwiftUI
import WidgetKit

// MARK: - WidgetArtExporter
// DEBUG-only. Renders the widget faces to PNG at arbitrary resolution, for
// marketing art / the website / the App Store — pristine tiles instead of
// crops off a Home Screen wallpaper.
//
// It works because the widget's view layers are deliberately WidgetKit-free
// where it counts (`OrlojFaceLayers`), so an `ImageRenderer` in the app
// process can draw them. The two widget sources are shared into this target
// via the project's membership-exception sets — the same mechanism the watch
// app uses for `OrlojFace.swift`.
//
// Driven by a launch argument so it never runs in a normal session:
//   xcrun simctl launch <udid> com.lorep.uk.Ephoemerous -shot exportart
// Files land in the app container's Documents/WidgetArt/.
@MainActor
enum WidgetArtExporter {

    /// Point sizes of the real widget families (iPhone 6.9" class). The
    /// faces are fully size-driven, so these are the honest proportions —
    /// `scale` below is what makes the export high-resolution.
    private static let families: [(name: String, size: CGSize, family: WidgetFamily)] = [
        ("small",  CGSize(width: 170, height: 170), .systemSmall),
        ("medium", CGSize(width: 364, height: 170), .systemMedium),
        ("large",  CGSize(width: 364, height: 382), .systemLarge),
    ]

    /// Render multiplier. 4 gives a 170pt tile at 680px — plenty for a
    /// website hero or an App Store panel. ▼ TWEAK ▼
    private static let scale: CGFloat = 4

    /// iOS draws every widget family with the same continuous corner.
    private static let cornerRadius: CGFloat = 26

    /// Renders every face and returns the directory they landed in.
    @discardableResult
    static func exportAll() -> URL? {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        let dir = docs.appendingPathComponent("WidgetArt", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        // The observer the app last parked at — same source the widgets read,
        // so the exported sky matches what the user actually sees. Falls back
        // to a scenic mid-northern origin.
        let origin = FavouritesStore().observerOrigin() ?? (latDeg: 43.77, lonDeg: 11.25)
        let now    = Date.now

        // ── The Orloj — the astrolabe, in the two families it supports.
        for f in families where f.name != "medium" {
            let face = OrlojFace(date: now, origin: origin, size: f.size)
            write(tile(size: f.size) { OrlojFaceLayers(face: face) },
                  to: dir, name: "orloj_\(f.name).png")
        }

        // ── The postcard — one tile per pinned object, at every family's
        // proportions AND its true treatment (`familyOverride`, since
        // `\.widgetFamily` can't be injected outside a widget host).
        let pins: [(String, ESkyObject)] = [
            ("moon",  .moon),
            ("sun",   .sun),
            ("orion", .constellation(.Ori)),
        ]
        for (label, obj) in pins {
            let entry = SkyObjectEntry(date:     now,
                                       captured: now,
                                       entity:   SkyObjectEntity(obj),
                                       origin:   origin)
            for f in families {
                let view = tile(size: f.size) {
                    SkyObjectWidgetView(entry: entry, familyOverride: f.family)
                }
                write(view, to: dir, name: "postcard_\(label)_\(f.name).png")
            }
        }

        // ── Named stars, SMALL only — the pocket-sized species. Resolved by
        // CATALOGUE name (`α Ori`), which is what the database is keyed on;
        // the tile itself shows the proper name via `displayName`.
        let starPins = ["α Ori", "α Per"]      // Betelgeuse, Mirfak
        let catalogue = StarDatabase.shared.workableStars
        for catName in starPins {
            guard let star = catalogue.first(where: { $0.name == catName }) else {
                ELogger.starDatabase("widget art: star not found — \(catName)")
                continue
            }
            let entry = SkyObjectEntry(date:     now,
                                       captured: now,
                                       entity:   SkyObjectEntity(.star(star)),
                                       origin:   origin)
            let size = CGSize(width: 170, height: 170)
            let slug = star.displayName.lowercased()
            write(tile(size: size) {
                      SkyObjectWidgetView(entry: entry, familyOverride: .systemSmall)
                  },
                  to: dir, name: "postcard_\(slug)_small.png")
        }

        // ── Share postcards — the real 4:5 card the share sheet sends,
        // rendered here so it can be eyeballed without a device.
        let cards: [(String, ESkyObject)] = [
            ("moon",  .moon),
            ("orion", .constellation(.Ori)),
        ]
        var starCard: ESkyObject?
        if let betelgeuse = StarDatabase.shared.workableStars
            .first(where: { $0.name == "α Ori" }) { starCard = .star(betelgeuse) }
        for (label, obj) in cards + (starCard.map { [("betelgeuse", $0)] } ?? []) {
            let postcard = SkyPostcard(object: obj, date: now,
                                       latDeg: origin.latDeg, lonDeg: origin.lonDeg,
                                       placeName: "Florence")
            if let data = try? postcard.pngData() {
                try? data.write(to: dir.appendingPathComponent("share_\(label).png"))
            }
        }

        ELogger.starDatabase("widget art exported to \(dir.path)")
        return dir
    }

    // MARK: Plumbing

    /// The face on its night background, cropped to the widget's corner —
    /// `containerBackground(for: .widget)` draws nothing outside a real
    /// widget host, so the background is supplied here.
    private static func tile<V: View>(size: CGSize,
                                      @ViewBuilder _ content: () -> V) -> some View {
        ZStack {
            EArtist.shared.canvasBackground
            content()
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    private static func write<V: View>(_ view: V, to dir: URL, name: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.uiImage, let data = image.pngData() else {
            ELogger.starDatabase("widget art FAILED: \(name)")
            return
        }
        try? data.write(to: dir.appendingPathComponent(name))
    }
}
#endif
