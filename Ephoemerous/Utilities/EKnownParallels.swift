
import SwiftUI


enum EKnownParallels: CaseIterable {
    
    case equator        
    case trCancer       
    case trCapr         
    case articCircle    
    case antarticCircle 
    
    var declination: Angle {
        switch self {
        case .equator        : .zero
        case .trCancer       : AstroConstants.tropicCancer
        case .trCapr         : AstroConstants.tropicCapricorn
        case .articCircle    : AstroConstants.arcticCircle
        case .antarticCircle : AstroConstants.antarcticCircle
        }
    }
}
