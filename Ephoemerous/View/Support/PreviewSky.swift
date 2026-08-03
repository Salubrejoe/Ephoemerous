#if DEBUG
import SwiftUI
// `Angle.spherePoint` lives in LoreKit; MEMBER_IMPORT_VISIBILITY needs it named.
import LoreKit

// MARK: - PreviewSky
// Scaffolding so the sky layers can be previewed at all.
//
// Every canvas and overlay draws through a `SkyCamera`, which needs an
// observer, a date and a projection before it will render a single star —
// so without a shared sample each layer would need its own hand-rolled
// camera, and they'd drift apart. One camera here, one night-sky container,
// and every layer gets a preview worth looking at.
//
// DEBUG-only: none of this reaches a shipping build.
enum PreviewSky {

    /// A clear winter evening over Florence — Orion up, plenty of bright
    /// stars in frame, so a layer preview actually shows something.
    static let date: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 15
        c.hour = 21; c.minute = 30
        c.timeZone = TimeZone(identifier: "Europe/Rome")
        return Calendar(identifier: .gregorian).date(from: c) ?? .now
    }()

    static let latitude  = Angle.degrees(43.77)
    static let longitude = Angle.degrees(11.25)

    /// Canvas size for a layer preview. Square, so the horizon disc fits
    /// whichever way a layer draws it.
    static let size = CGSize(width: 390, height: 390)

    /// The observer's view — same construction the app uses, so a preview
    /// shows the real projection rather than an approximation.
    @MainActor
    static var camera: SkyCamera {
        let viewpoint = Projection.Viewpoint(
            originVector: Angle.spherePoint(latitude: latitude, longitude: longitude),
            planeVector:  Angle.spherePoint(latitude: .radians(-latitude.radians),
                                            longitude: longitude + .radians(.pi)))
        return SkyCamera(scale: (size.width - 48) / 4,
                         offset: .zero,
                         size: size,
                         viewpoint: viewpoint,
                         sidereal: -Precession.gmstSiderealOffset(for: date))
    }

    /// A handful of bright, proper-named stars — enough for labels and
    /// badges to have something to attach to.
    @MainActor
    static var brightStars: [Star] {
        Array(StarDatabase.shared.workableStars
            .filter { $0.properName != nil }
            .sorted { $0.magnitude < $1.magnitude }
            .prefix(12))
    }

    @MainActor
    static var someStar: Star {
        brightStars.first ?? Star.mockStars[0]
    }

    /// The night behind a layer. Previews of a bare overlay on the default
    /// light background are unreadable — every mark is tuned for the dark.
    static func night<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            Artist.shared.canvasBackground
            content()
        }
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, .dark)
    }
}
#endif
