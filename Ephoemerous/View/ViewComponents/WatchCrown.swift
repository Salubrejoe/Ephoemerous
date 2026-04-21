
import SwiftUI


struct WatchCrown: View {
    @Environment(EAppState.self) var state
    
    var body: some View {
        ZStack {
            
            Circle()
                .stroke(lineWidth: 20)
                .fill(.ultraThinMaterial)
//                .glassEffect()
                .frame(
                    width: dialOffset*2,
                    height: dialOffset*2
                )
            
            ForEach(0..<24) { index in
                VStack(spacing: 12) {
                    Text("\(index)")
                }
                .font(hourMarkerFont)
                .offset(y: -dialOffset)
                .rotationEffect(angleForHourMarker(index))
            }
            
            ForEach(0..<96) { index in
                if index % 4 != 0 {
                    Text("|")
                        .font(fifteenMinuteMarkerFont)
                        .offset(y: -dialOffset)
                        .rotationEffect(angleForFiteenMinutesMarker(index))
                }
            }
        }
        .foregroundStyle(.secondary)
        .font(.caption)
        .fontDesign(.monospaced)
    }
}


// MARK: - Helpers
extension WatchCrown {
    
    var hourMarkerFont: Font { .system(size: scale / 5, weight: .bold) }
//    var hourMarkerFont: Font { .system(size: state.scale / 10, weight: .bold) }
    var fifteenMinuteMarkerFont: Font { .system(size: scale / 20, weight: .semibold) }
//    var fifteenMinuteMarkerFont: Font { .system(size: state.scale / 20, weight: .semibold) }
    
//    var scale: Double { state.scale }
    var scale: Double { 50.0 }
    
    var dialOffset: Double { scale * 3.4 }
    
    
    func angleForHourMarker(_ index: Int) -> Angle {
        Angle.degrees(Double(index) / 24 * 360) + Angle.degrees(180)
    }
    
    func angleForFiteenMinutesMarker(_ index: Int) -> Angle {
        Angle.degrees(Double(index) / 96 * 360)
    }
}

