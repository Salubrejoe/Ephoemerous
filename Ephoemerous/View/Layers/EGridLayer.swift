import simd

// MARK: - Layer protocol
// One method, one role: draw into the per-frame graphics context.
// The `artist` accessor is the shared `EArtist` singleton — every
// layer needs it, so it lives here as a default-implemented
// property instead of being redeclared on every conformer.

protocol EGridLayer {
    typealias Vector3D = SIMD3<Double>
    func draw(in dc: inout EGraphicContext)
}

extension EGridLayer {
    var artist: EArtist { EArtist.shared }
}
