import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

// MARK: - SkyPostcard
// The shareable form of a sky object: a PNG of `SkyShareCard`, plus the
// words that travel with it.
//
// `Transferable` renders LAZILY — the image is only drawn once the user
// picks a destination in the share sheet, so tapping the share button
// stays instant no matter how dense the sky is.
struct SkyPostcard: Transferable {

    let object:    SkyObject
    let date:      Date
    let latDeg:    Double
    let lonDeg:    Double
    let placeName: String?

    /// Points → pixels. 3 gives 1200 × 1500 from the 400 × 500 design,
    /// which is comfortably past what Messages or Instagram will show.
    static let renderScale: CGFloat = 3

    /// Where the postcard sends people. The site carries the TestFlight
    /// link, so one URL serves both "look at this" and "let me try it".
    static let siteURL = URL(string: "https://licurgen.co.uk/ephoemerous")!

    // MARK: Words

    /// The message body — what lands in Messages or Mail alongside the
    /// image. Deliberately reads like a person wrote it. MainActor because
    /// the alt/az line projects through the shared sky pipeline.
    @MainActor
    var message: String {
        var line = object.displayName
        if let altAz = Self.altAzLine(object: object, date: date,
                                      latDeg: latDeg, lonDeg: lonDeg) {
            line += " — \(altAz)"
        }
        if let placeName, !placeName.isEmpty { line += ", from \(placeName)" }
        return "\(line)\n\(Self.siteURL.absoluteString)"
    }

    var fileName: String {
        let slug = object.displayName
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
        return "ephemerous-\(slug)"
    }

    // MARK: Rendering

    @MainActor
    func pngData() throws -> Data {
        let renderer = ImageRenderer(content: card)
        renderer.scale = Self.renderScale
        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }

    private var card: SkyShareCard {
        SkyShareCard(object: object, date: date,
                     latDeg: latDeg, lonDeg: lonDeg, placeName: placeName)
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { postcard in
            try await MainActor.run { try postcard.pngData() }
        }
        .suggestedFileName { $0.fileName + ".png" }
    }

    // MARK: Alt/az for the message line

    /// Same maths as `SkySnapshot.altitudeAzimuthLabel`, reachable without
    /// building a whole snapshot just to write one sentence. Nil for
    /// constellations, which have no single direction to point at.
    @MainActor
    private static func altAzLine(object: SkyObject, date: Date,
                                  latDeg: Double, lonDeg: Double) -> String? {
        let snapshot = SkySnapshot(entity: SkyObjectEntity(object),
                                   date:   date,
                                   origin: (latDeg: latDeg, lonDeg: lonDeg),
                                   size:   SkyShareCard.size,
                                   isLandscape: false)
        return snapshot.altitudeAzimuthLabel
    }
}

// MARK: - AppState → postcard

extension AppState {

    /// The postcard for `obj` as the sky stands in THIS session — the
    /// observer's origin, the observation date currently on screen (so a
    /// card wound forward with the date crown shares that sky, not now),
    /// and the resolved town when the toolbar has one.
    func postcard(for obj: SkyObject) -> SkyPostcard {
        SkyPostcard(object:    obj,
                    date:      renderedObservationDate,
                    latDeg:    origin.latitude.degrees,
                    lonDeg:    origin.longitude.degrees,
                    placeName: localityName)
    }
}
