import SwiftUI

// MARK: - EPalette myth accessor (DEPRECATED)
// The constellation-myth → gradient lookup, moved out of the live palette
// with the retired myth taxonomy. The per-cycle colour data (perseus /
// hercules / … / mythNone) still lives on `EPalette` as plain stored
// values; only this enum-driven accessor is deprecated.
extension EPalette {
    /// Constellation myth → badge gradient.
    func myth(_ kind: POIConstellationMyth) -> Gradient {
        switch kind {
        case .perseus:  return perseus
        case .hercules: return hercules
        case .argo:     return argo
        case .zeus:     return zeus
        case .orion:    return orion
        case .orpheus:  return orpheus
        case .none:     return mythNone
        }
    }
}
