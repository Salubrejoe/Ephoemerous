
import Foundation


struct EZodiacSign: Identifiable {
  var id: Int { index }
  let index  : Int
  let symbol : String
  
  static let zodiac: [EZodiacSign] = [
    .init(index: 1,  symbol: "♈︎"),
    .init(index: 2,  symbol: "♉︎"),
    .init(index: 3,  symbol: "♊︎"),
    .init(index: 4,  symbol: "♋︎"),
    .init(index: 5,  symbol: "♌︎"),
    .init(index: 6,  symbol: "♍︎"),
    .init(index: 7,  symbol: "♎︎"),
    .init(index: 8,  symbol: "♏︎"),
    .init(index: 9,  symbol: "♐︎"),
    .init(index: 10, symbol: "♑︎"),
    .init(index: 11, symbol: "♒︎"),
    .init(index: 12, symbol: "♓︎")
  ]
}
