
import SwiftUI


struct ESkyObjectRow: View {
    let obj: ESkyObject
    var body: some View {
        switch obj {
        case .star(let s):
            EStarRowView(star: s)
        case .sun:
            ESolarBodyRow(
                name: "Sun",
                subtitle: "G-type star",
                color: .yellow,
                magnitude: -26.74,
                symbol: "sun.max.fill"
            )
        case .moon:
            ESolarBodyRow(
                name: "Moon",
                subtitle: "Natural satellite",
                color: .white,
                magnitude: -12.6,
                symbol: "moon.fill"
            )
        case .planet(let p):
            ESolarBodyRow(
                name: p.name,
                subtitle: "Planet",
                color: p.color,
                magnitude: p.baseMagnitude,
                symbol: "circle.fill"
            )
        case .constellation(let c):
            EConstellationRow(constellation: c)
        }
    }
}
