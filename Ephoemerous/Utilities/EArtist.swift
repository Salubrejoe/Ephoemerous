
import SwiftUI


struct EArtist {
    static let shared = EArtist()
    
    let color       : Color   = .primary.opacity(0.5)
    let width       : Double = 0.1
    let thickWidth  : Double = 0.5
    
    let eclColor    : Color   = .yellow.opacity(0.2)
    let eclWidth    : Double = 2
    
    let horColor    : Color   = .baseOrange.opacity(0.85)
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
        let phase   = ra * AstroConstants.twinklePhaseRA + dec * AstroConstants.twinklePhaseDec
        let twinkle = 1.0 + AstroConstants.twinkleAmplitude * sin(dc.state.animationTime * AstroConstants.twinkleFrequency + phase)
        let r = max(AstroConstants.dotMinRadius, (AstroConstants.dotScale - star.magnitude) * AstroConstants.dotFactor) * twinkle
        return r
    }
}
