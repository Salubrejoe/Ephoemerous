import Foundation


class StarDatabase {
  static let shared = StarDatabase()
  private(set) var stars: [StarData] = []
  
  /// Every usable star, ONE entry per designation, built once.
  ///
  /// Two things happen here that everything downstream depends on:
  ///
  /// • DE-DUPLICATION. BSC5 lists the components of a visual double as
  ///   SEPARATE records sharing one designation — Mizar is HR 5054 (mag
  ///   2.27) and HR 5055 (mag 3.95), both "79Zet UMa". Rendered naively
  ///   that draws two badges and two identical labels a few arcseconds
  ///   apart. 64 designations are doubled this way. We keep the BRIGHTEST
  ///   component as the system's representative; the companions belong in
  ///   the detail sheet, not as a second POI on the canvas.
  ///
  /// • CACHING. This used to rebuild ~9k structs on EVERY access, and it
  ///   is read from several layers per frame. Built once now — which also
  ///   makes `Star` instances stable for the whole session.
  private(set) lazy var workableStars: [Star] = {
      let workable = stars.map(Star.init(from:))
          .filter { $0.displayName != "Unknown" }
      // Brightest first, so `uniqued(by:)` keeps the primary component.
      let byBrightness = workable.sorted { $0.magnitude < $1.magnitude }
      var seen = Set<String>()
      let deduped = byBrightness.filter { seen.insert($0.name).inserted }
      Logger.starDatabase("\(deduped.count) stars (\(workable.count - deduped.count) companion records folded in)")
      return deduped
  }()
    
    var listableStars: [Star] {
        workableStars
            .filter { star in
                // Keep stars whose displayName starts with a Greek letter
                let name = star.displayName
                guard let first = name.first else { return false }
                let greekLetters = "αβγδεζηθικλμνξοπρστυφχψωΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ"
                return greekLetters.contains(first) || star.properName != nil
            }
    }
  
  func stars(for constellations: [Constellation]) -> [Star] {
    var stars = [Star]()
    for star in workableStars {
      for constellation in constellations {
        if star.constellation == constellation {
          stars.append(star)
        }
      }
    }
    return stars
  }
 
  private init() { loadStars() }
  
  private func loadStars() {
    guard let url = Bundle.main.url(forResource: "bsc5", withExtension: "json") else {
      Logger.starDatabase("JSON file not found")
      return
    }
    
    do {
      let data = try Data(contentsOf: url)
      let decodedStars = try JSONDecoder().decode([StarData].self, from: data)
      self.stars = decodedStars
    } catch {
      Logger.starDatabase("Error decoding JSON: \(error)")
    }
  }
  
  func findStar(named starName: String) -> StarData? {
    return stars.first { $0.name?.lowercased() == starName.lowercased() }
  }
}

