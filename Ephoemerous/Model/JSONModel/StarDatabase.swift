
import Foundation


class StarDatabase {
  static let shared = StarDatabase()
  private(set) var stars: [StarData] = []
  
  var workableStars: [EStar] {
      let workable: [EStar] = stars.map { .init(from: $0) }
      ELogger.starDatabase(workable.count.description)
      return workable
  }
  
  func stars(for constellations: [EConstellation]) -> [EStar] {
    var stars = [EStar]()
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
      ELogger.starDatabase("JSON file not found")
      return
    }
    
    do {
      let data = try Data(contentsOf: url)
      let decodedStars = try JSONDecoder().decode([StarData].self, from: data)
      self.stars = decodedStars
    } catch {
      ELogger.starDatabase("Error decoding JSON: \(error)")
    }
  }
  
  func findStar(named starName: String) -> StarData? {
    return stars.first { $0.name?.lowercased() == starName.lowercased() }
  }
}
