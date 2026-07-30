import WidgetKit
import SwiftUI
import LoreKit
import simd

// MARK: - OrlojWidget
// The Prague astronomical clock, superimposed on the app's REAL NorthOUT
// projection — not a lookalike drawing, the SAME projection. NorthOUT's
// scale derivation already uses ρ = 2·tan((δ+90°)/2) for a declination
// circle (see EAppState+Space.northOutDefaultScale); that is EXACTLY
// DeprecationStation/Orloj/EOrlojGeometry's own r = tan(45°+δ/2) formula.
// The Orloj and NorthOUT are the same stereographic projection from the
// observer's hidden celestial pole (eye = NCP / tangent plane = SCP in
// the north; mirrored in the south) — one was built for a 1410
// astrolabe, the other for this app; they were always the same math.
// Everything is SAMPLED through the real `SkyCamera` (the codebase's
// established pattern — CelestialGridCanvas, AlmucantarCurve), so it's
// exact for the viewer's actual latitude with no separate handedness
// reasoning.
//
// The face itself — geometry AND the composed layers — lives in
// `OrlojFace.swift` (OrlojFace + OrlojFaceLayers), SHARED with the watch
// app, where the Digital Crown turns the same instrument through time.
// This file is only the WidgetKit mount: provider, entry, configuration.
struct OrlojProvider: TimelineProvider {

    func placeholder(in context: Context) -> OrlojEntry {
        OrlojEntry(date: .now, origin: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (OrlojEntry) -> Void) {
        Task { @MainActor in
            completion(OrlojEntry(date: .now, origin: FavouritesStore().observerOrigin()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OrlojEntry>) -> Void) {
        Task { @MainActor in
            let origin = FavouritesStore().observerOrigin()
            let now    = Date.now
            // 15-minute beats — the hands and unequal-hour arcs visibly
            // advance between refreshes, like the real clock's mechanism.
            let entries = stride(from: 0, through: 60, by: 15).map { m in
                OrlojEntry(date: now.addingTimeInterval(Double(m) * 60), origin: origin)
            }
            completion(Timeline(entries: entries,
                                policy: .after(now.addingTimeInterval(75 * 60))))
        }
    }
}

struct OrlojEntry: TimelineEntry {
    let date:   Date
    /// Observer origin the app last parked at — nil before the app has
    /// ever backgrounded; falls back to Prague itself, fittingly.
    let origin: (latDeg: Double, lonDeg: Double)?
}

// MARK: - Entry view
// A thin mount: build the face for the entry's date and hand it to the
// shared `OrlojFaceLayers` (see OrlojFace.swift).
struct OrlojWidgetView: View {
    var entry: OrlojEntry

    /// How the Home Screen is rendering us. `.fullColor` is the normal
    /// tile — untouched. The tinted / "Clear" themes hand the widget to a
    /// luminance map instead (`.vibrant` / `.accented`), where every fill,
    /// glow and shadow resolves to solid white: the glass bands fuse into
    /// fat rings and the numerals bloat into blocks. Those modes get the
    /// line-art face (see `OrlojFaceLayers.lineArt`).
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        GeometryReader { geo in
            OrlojFaceLayers(face: OrlojFace(date:   entry.date,
                                            origin: entry.origin,
                                            size:   geo.size),
                            lineArt: renderingMode != .fullColor)
        }
        .containerBackground(for: .widget) {
            EArtist.shared.canvasBackground
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Widget

struct OrlojWidget: Widget {
    let kind: String = "OrlojWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OrlojProvider()) { entry in
            OrlojWidgetView(entry: entry)
        }
        .configurationDisplayName("Orloj")
        .description("Your sky, in the geometry of the Prague astronomical clock.")
        .supportedFamilies([.systemSmall, .systemLarge])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemLarge) {
    OrlojWidget()
} timeline: {
    OrlojEntry(date: .now, origin: nil)
}

#Preview(as: .systemSmall) {
    OrlojWidget()
} timeline: {
    OrlojEntry(date: .now, origin: nil)
}
