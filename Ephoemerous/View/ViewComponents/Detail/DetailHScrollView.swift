
import SwiftUI


struct DetailHScrollView: View {
    struct Stat: Identifiable {
        enum StatType {
            case rightAscenscion, declination, distance, magnitude, diameter, hrClass, period
            
            var symbol: Symbol {
                switch self {
                case .rightAscenscion:
                        .rightAscension
                case .declination:
                        .declination
                case .distance:
                        .distance
                case .magnitude:
                        .magnitude
                case .diameter:
                        .diameter
                case .hrClass:
                        .hrClass
                case .period:
                        .period
                }
            }
        }
        let id = UUID()
        let value: String
        let statType:  StatType
    }
    
    let stats: [Stat]
    
    var body: some View {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(.clear)
                        .frame(width: 8, height: 10)
                ForEach(stats) { stat in
                    DetailTile(icon: stat.statType.symbol.rawValue, value: stat.value)
                }
            }
                
        }
            .scrollIndicators(.hidden)
    }
}


struct DetailTile: View {
    let icon:  String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: 120)
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 22).fill(.ultraThinMaterial)
        )
    }
}
