import Foundation
import SwiftUI
import simd

// MARK: - DeepSkyObject
// An open cluster, nebula or Local Group galaxy from `deepsky.json` — the
// Messier ones plus a few famous named others, reduced from OpenNGC (Mattia Verga, CC BY-SA 4.0; the file carries the same licence
// and its credit). Positions are J2000, like the stars.
struct DeepSkyObject: Identifiable, Decodable, Hashable {
    static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

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
    /// IAU abbreviation of the constellation it sits in ("Tau").
    let const:   String?
    /// Light-years, from the catalogue's parallax, where it has one.
    let distance: Double?

    var constellation: Constellation? { const.flatMap(Constellation.init(rawValue:)) }

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
    /// before the next: the Pleiades, the Hyades, Coma, the Beehive,
    /// Ptolemy's Cluster and the Alpha Persei Cluster so far. The rest stay
    /// in the catalogue, undrawn.
    static let shownClusters: Set<String> = ["M45", "C041", "Mel111", "M44", "M7", "Mel020"]

    /// An open cluster that's on the sky now.
    var isShownCluster: Bool { badgeKind == .cluster && Self.shownClusters.contains(id) }

    /// Where a cluster's name is pinned — a point ON THE SKY, so the name
    /// rides with the stars at every zoom. Picked by eye, cluster by
    /// cluster, in a clear patch just off the middle (the middle is often a
    /// star — Alcyone, Mirfak). Degrees, J2000. ▼ TWEAK ▼
    private static let nameAnchors: [String: (ra: Double, dec: Double)] = [
        "M45":    (56.90,  23.80),     // south of Alcyone, between Merope and Atlas
        "C041":   (66.30,  15.40),     // inside the V, west of Chamukuy
        "Mel111": (186.27, 26.10),     // the open middle
        "M44":    (130.10, 19.25),     // south of ε Cnc
        "M7":     (268.47, -34.79),    // the open middle
        "Mel020": (52.00,  48.60),     // south of Mirfak
    ]

    /// Catalogued stars inside each cluster that are confirmed MEMBERS —
    /// so they sit at the cluster's distance even where we hold no
    /// measurement of their own. Only the ones the literature agrees on;
    /// a star whose membership is in doubt is left off, not guessed.
    /// Star names as `Star.name` builds them. ▼ ADD as confirmed ▼
    private static let members: [String: Set<String>] = [
        "M45":    ["η Tau", "16 Tau", "17 Tau", "18 Tau", "19 Tau", "20 Tau",
                   "21 Tau", "22 Tau", "23 Tau", "27 Tau", "28 Tau"],
        "C041":   ["θ Tau", "γ Tau", "δ Tau", "ε Tau", "71 Tau", "ρ Tau"],
        "Mel111": ["12 Com", "13 Com", "14 Com", "16 Com", "17 Com", "21 Com"],
        "M44":    ["ε Cnc", "39 Cnc"],
        "Mel020": ["α Per", "34 Per"],
    ]

    func isMember(_ star: Star) -> Bool { Self.members[id]?.contains(star.name) == true }

    /// The sky point a cluster's name is centred on.
    var nameVector: SIMD3<Double> {
        guard let a = Self.nameAnchors[id] else { return equatorialVector }
        return Precession.equatorialVector(ra: .degrees(a.ra), dec: .degrees(a.dec))
    }

    /// "Open cluster", "Nebula"… — what the card's subtitle calls it.
    var kindName: String {
        switch kind {
        case .galaxy:    return String(localized: "Galaxy")
        case .open:      return String(localized: "Open cluster")
        case .globular:  return String(localized: "Globular cluster")
        case .nebula:    return String(localized: "Nebula")
        case .planetary: return String(localized: "Planetary nebula")
        }
    }

    /// The catalogue name to print: "M45", "NGC 2264" — and the short
    /// codes spelled out: "Caldwell 41", "Melotte 111".
    var designation: String {
        if id.hasPrefix("C"), let n = Int(id.dropFirst()) { return "Caldwell \(n)" }
        if id.hasPrefix("Mel"), let n = Int(id.dropFirst(3)) { return "Melotte \(n)" }
        return id
    }

    /// What the label says: the common name where there is one, else the
    /// catalogue designation ("M13", "NGC 7789").
    var label: String { name ?? id }

    var equatorialVector: SIMD3<Double> {
        Precession.equatorialVector(ra: .degrees(ra), dec: .degrees(dec))
    }

    private enum CodingKeys: String, CodingKey {
        case id, catalog, name, kind, ra, dec, major, minor, angle, mag, const, distance
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
