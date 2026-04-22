
import SwiftUI


struct EArtist {
    static let shared = EArtist()
    
    let color       : Color   = .primary.opacity(0.5)
    let width       : Double = 0.1
    let thickWidth  : Double = 0.5
    
    let eclColor    : Color   = .yellow.opacity(0.2)
    let eclWidth    : Double = 2
    
    let horColor    : Color   = .green.opacity(0.2)
    let horWidth    : Double = 0.5
    
    
    func starPointFallsWithinMarigin(_ screenPoint: CGPoint, in dc: EGraphicContext, margin: Double = 20) -> Bool {
        screenPoint.x > -margin &&
        screenPoint.x < dc.size.width + margin &&
        screenPoint.y > -margin &&
        screenPoint.y < dc.size.height + margin
    }
    
    func starRadius(_ star: EStar, in dc: EGraphicContext) -> Double {
        let ra  = star.rightAscension.radians
        let dec = star.declination.radians
        let phase   = ra * 17.3 + dec * 7.9
        let twinkle = 1.0 + 0.2 * sin(dc.state.animationTime * 2.5 + phase)
        let r = max(0.6, (6.0 - star.magnitude) * 0.55) * twinkle
        return r/2
    }
}
