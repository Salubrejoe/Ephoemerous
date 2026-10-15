import Foundation
import SwiftUI
import simd

// MARK: - DeepSkyObject
// An open cluster, nebula or Local Group galaxy from `deepsky.json` — the
// Messier ones plus a few famous named others, reduced from OpenNGC (Mattia Verga, CC BY-SA 4.0; the file carries the same licence
// and its credit). Positions are J2000, like the stars.
struct DeepSkyObject: Identifiable, Decodable {
    enum Kind: String, Decodable { case galaxy, open, globular, nebula, planetary }

    /// "M31", or the catalogue name where there's no Messier number.
    let id:      String
    /// "NGC 224".
    let catalog: String
    /// "Andromeda Galaxy", where it has a common name.
    let name:    String?
    let kind:    Kind
    /// Degrees, J2000.
    let ra, dec: Double
    /// Apparent size in arcminutes, and the major axis's position angle in
    /// degrees east of north — where the catalogue knows them.
    let major, minor, angle: Double?
    let mag:     Double?

    var isMessier: Bool { id.hasPrefix("M") }

    /// Which of the three badges it wears.
    var badgeKind: DeepSkyKind {
        switch kind {
        case .galaxy:              return .galaxy
        case .open, .globular:     return .cluster
        case .nebula, .planetary:  return .nebula
        }
    }

    var poiCategory: POICategory { .deepSky(badgeKind, messier: isMessier) }

    /// Open clusters come onto the sky one at a time, each checked by eye
    /// before the next: the Pleiades, the Hyades and Coma so far. The rest
    /// stay in the catalogue, undrawn.
    static let shownClusters: Set<String> = ["M45", "C041", "Mel111"]

    /// An open cluster that's on the sky now.
    var isShownCluster: Bool { badgeKind == .cluster && Self.shownClusters.contains(id) }

    /// What the label says: the common name where there is one, else the
    /// catalogue designation ("M13", "NGC 7789").
    var label: String { name ?? id }

    var equatorialVector: SIMD3<Double> {
        Precession.equatorialVector(ra: .degrees(ra), dec: .degrees(dec))
    }

    private enum CodingKeys: String, CodingKey {
        case id, catalog, name, kind, ra, dec, major, minor, angle, mag
    }
}

// MARK: - DeepSkyCatalog
enum DeepSkyCatalog {
    private struct File: Decodable { let objects: [DeepSkyObject] }

    /// Brightest first, loaded once.
    static let objects: [DeepSkyObject] = {
        guard let url  = Bundle.main.url(forResource: "deepsky", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return file.objects
    }()
}
