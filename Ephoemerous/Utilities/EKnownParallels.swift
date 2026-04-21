
import SwiftUI


enum EKnownParallels: CaseIterable {
    
    case equator        
    case trCancer       
    case trCapr         
    case articCircle    
    case antarticCircle 
    
    var declination: Angle {
        switch self {
        case .equator        : Angle.degrees(0.0)
        case .trCancer       : Angle.degrees(23.4393)
        case .trCapr         : Angle.degrees(-23.4393)
        case .articCircle    : Angle.degrees(66.5607)
        case .antarticCircle : Angle.degrees(-66.5607)
        }
    }
}
