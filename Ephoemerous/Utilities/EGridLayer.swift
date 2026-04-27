import simd

// MARK: - Layer protocol

protocol EGridLayer {
    typealias Vector3D = SIMD3<Double>
    func draw(in dc: inout EGraphicContext)
}
