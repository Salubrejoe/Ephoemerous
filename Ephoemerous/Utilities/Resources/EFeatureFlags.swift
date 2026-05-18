import Foundation

// MARK: - EFeatureFlags
// Compile-time prototype switches. Flip a value and rebuild to A/B.
enum EFeatureFlags {

    /// Watch-crown ring rendering.
    /// `true`  → vector strokes (no offscreen material/glass/mask raster,
    ///           so no re-rasterization "pop" when zooming past ~scale 90).
    /// `false` → the original glass / ultraThinMaterial annuli.
    static let vectorWatchRings: Bool = true

    /// Watch-crown geometry.
    /// `true`  → bands/equator projected through the SAME EProjection
    ///           pipeline the sky uses, so the crown is glued to the star
    ///           field at every zoom (no drift / scale-band snap).
    /// `false` → the original SProjection crown (drifts; for A/B only).
    static let skyAnchoredCrown: Bool = true
}
