#if canImport(UIKit)

import SwiftUI
import Vision
import UIKit

// MARK: - SFSymbolShape
// Any SF Symbol exposed as a SwiftUI `Shape`, mirroring `Squircle`'s
// API (`path(in:)` + `vertices(in:segments:)` so the rim can be fed
// through any sampled-curve pipeline).
//
// Why Vision instead of Core Text: SF Symbols aren't really font
// glyphs you can resolve by PUA codepoint via `UIFont.systemFont(...)`
// — Apple ships them as internal vector data, not as cascading font
// glyphs. The reliable public path is:
//   1. Rasterise the symbol via `UIImage(systemName:)` onto a
//      high-contrast bitmap.
//   2. Run `VNDetectContoursRequest` to extract its silhouette as a
//      normalised `CGPath`.
//   3. Cache per (name, weight) so step 1+2 happen at most once per
//      symbol; subsequent `path(in:)` calls are pure transform comp.
//
// Caveats:
//   • Silhouette only. Hierarchical / palette / multicolour symbols
//     collapse to their outermost outline.
//   • Very fine details may simplify slightly under contour detection.
//     Bump `referencePointSize` if the symbol's small features matter.
//
// Availability: `#if canImport(UIKit)` — the resolver uses
// `UIImage(systemName:)` and friends, which only exist where UIKit is.
// On macOS this file contributes no symbols; LoreKit still compiles.
public struct SFSymbolShape: Shape {

    public var systemName : String
    public var weight     : UIImage.SymbolWeight
    public var rotation   : Angle

    public init(systemName: String,
                weight: UIImage.SymbolWeight = .regular,
                rotation: Angle              = .zero) {
        self.systemName = systemName
        self.weight     = weight
        self.rotation   = rotation
    }

    /// Reference render size for the symbol bitmap before contour
    /// detection. Bigger = sharper detail at higher cost — `256` is a
    /// reasonable sweet spot for most symbols.
    ///
    /// `nonisolated(unsafe)` because in practice this is only ever
    /// touched from the main thread (Shape resolution runs in the
    /// SwiftUI render pass), and a one-time global tuning knob isn't
    /// worth an actor.
    public nonisolated(unsafe) static var referencePointSize: CGFloat = 256

    public func path(in rect: CGRect) -> Path {
        let key = CacheKey(name: systemName, weightRaw: weight.rawValue)
        guard let cgPath = Self.cachedOrResolved(key: key, weight: weight) else { return Path() }
        return transformed(cgPath, in: rect)
    }

    /// Sampled rim of the symbol's outline at evenly-spaced arclength
    /// positions across all subpaths concatenated. Mirrors
    /// `Squircle.vertices(in:segments:)` so the two shapes feed the
    /// same stroke-curve pipeline.
    public func vertices(in rect: CGRect, segments: Int = 240) -> [CGPoint] {
        path(in: rect).cgPath.evenlySpacedPoints(count: segments + 1)
    }

    // MARK: Transform

    /// Centre the resolved silhouette path in `rect`, uniform-scale to
    /// fit the smaller dimension, rotate around the rect's centre.
    /// Vision returns paths in upper-left-origin normalised coords —
    /// matches SwiftUI / Core Graphics, no Y flip needed.
    private func transformed(_ cgPath: CGPath, in rect: CGRect) -> Path {
        let bbox = cgPath.boundingBoxOfPath
        guard bbox.width > 0, bbox.height > 0 else { return Path() }
        let scale = min(rect.width / bbox.width, rect.height / bbox.height)
        var t = CGAffineTransform.identity
            .translatedBy(x: rect.midX,    y: rect.midY)
            .rotated(by:   rotation.radians)
            .scaledBy(x:   scale,          y: scale)
            .translatedBy(x: -bbox.midX,   y: -bbox.midY)
        return Path(cgPath.copy(using: &t) ?? cgPath)
    }
}

// MARK: - Resolution + cache

private extension SFSymbolShape {

    /// Keyed on the weight's raw `Int` rather than `UIImage.SymbolWeight`
    /// so the type stays plainly `Sendable` — `UIImage.SymbolWeight` is
    /// main-actor-isolated in Swift 6, which would taint the synthesized
    /// `Hashable` conformance and conflict with `nonisolated(unsafe)`
    /// static storage.
    struct CacheKey: Hashable, Sendable {
        let name      : String
        let weightRaw : Int
    }

    /// Process-wide cache of resolved silhouettes. SF Symbol paths are
    /// immutable, so once we've paid for the bitmap + Vision pass we
    /// keep the result for the lifetime of the app.
    nonisolated(unsafe) static var pathCache: [CacheKey: CGPath] = [:]

    static func cachedOrResolved(key: CacheKey, weight: UIImage.SymbolWeight) -> CGPath? {
        if let cached = pathCache[key] { return cached }
        guard let cgPath = resolve(name: key.name, weight: weight) else { return nil }
        pathCache[key] = cgPath
        return cgPath
    }

    static func resolve(name: String, weight: UIImage.SymbolWeight) -> CGPath? {
        // 1. Pull the SF Symbol UIImage at a generous reference size.
        let config = UIImage.SymbolConfiguration(pointSize: referencePointSize, weight: weight)
        guard let image = UIImage(systemName: name, withConfiguration: config) else {
            return nil
        }

        // 2. Rasterise as black-on-white so the detector has clean
        //    high-contrast input. Opaque format avoids alpha quirks.
        let size            = image.size
        let format          = UIGraphicsImageRendererFormat()
        format.opaque       = true
        format.scale        = 1
        let renderer        = UIGraphicsImageRenderer(size: size, format: format)
        let bitmap          = renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            image.withTintColor(.black, renderingMode: .alwaysOriginal)
                 .draw(at: .zero)
        }
        guard let cgImage = bitmap.cgImage else { return nil }

        // 3. Vision contour detection.
        let request                = VNDetectContoursRequest()
        request.contrastAdjustment = 1.5
        request.detectsDarkOnLight = true
        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first else { return nil }

        // 4. `normalizedPath` concatenates every detected contour into
        //    a single CGPath in [0, 1] × [0, 1] coords — exactly what
        //    `transformed(_:in:)` expects.
        return observation.normalizedPath
    }
}

// MARK: - CGPath flattening + arclength sampling

private extension CGPath {

    /// Walks the path, flattening curves into straight segments via
    /// recursive de Casteljau subdivision, then returns `count`
    /// evenly-spaced points along the cumulative arclength. Multiple
    /// subpaths concatenate end-to-end before sampling.
    func evenlySpacedPoints(count: Int) -> [CGPoint] {
        guard count > 0 else { return [] }
        var segments: [(CGPoint, CGPoint)] = []
        var current      = CGPoint.zero
        var subpathStart = CGPoint.zero

        applyWithBlock { ptr in
            let el  = ptr.pointee
            let pts = el.points
            switch el.type {
            case .moveToPoint:
                current      = pts[0]
                subpathStart = pts[0]
            case .addLineToPoint:
                segments.append((current, pts[0]))
                current = pts[0]
            case .addQuadCurveToPoint:
                flattenQuad(from: current, cp: pts[0], to: pts[1], into: &segments)
                current = pts[1]
            case .addCurveToPoint:
                flattenCubic(from: current, c1: pts[0], c2: pts[1], to: pts[2], into: &segments)
                current = pts[2]
            case .closeSubpath:
                segments.append((current, subpathStart))
                current = subpathStart
            @unknown default:
                break
            }
        }

        // Cumulative arclengths, including the leading zero.
        var lengths: [CGFloat] = [0]
        lengths.reserveCapacity(segments.count + 1)
        var total: CGFloat = 0
        for (a, b) in segments {
            total += hypot(b.x - a.x, b.y - a.y)
            lengths.append(total)
        }
        guard total > 0 else { return [] }

        // Walk monotonically — sample positions are sorted, so we can
        // advance the segment cursor without re-scanning from zero.
        var out = [CGPoint]()
        out.reserveCapacity(count)
        var cursor = 0
        for i in 0..<count {
            let s = CGFloat(i) / CGFloat(max(count - 1, 1)) * total
            while cursor < segments.count - 1 && lengths[cursor + 1] < s {
                cursor += 1
            }
            let segLen = lengths[cursor + 1] - lengths[cursor]
            let t      = segLen > 0 ? (s - lengths[cursor]) / segLen : 0
            let (a, b) = segments[cursor]
            out.append(CGPoint(x: a.x + (b.x - a.x) * t,
                               y: a.y + (b.y - a.y) * t))
        }
        return out
    }
}

private let flattenMaxDepth      = 6
private let flattenToleranceSqPx : CGFloat = 0.000025   // tight, since Vision paths are normalised 0…1

private func flattenQuad(from a: CGPoint, cp: CGPoint, to b: CGPoint,
                         into segments: inout [(CGPoint, CGPoint)],
                         depth: Int = 0) {
    let dx = (a.x + b.x) * 0.5 - cp.x
    let dy = (a.y + b.y) * 0.5 - cp.y
    if depth >= flattenMaxDepth || dx * dx + dy * dy < flattenToleranceSqPx {
        segments.append((a, b))
        return
    }
    let m1  = midpoint(a, cp)
    let m2  = midpoint(cp, b)
    let mid = midpoint(m1, m2)
    flattenQuad(from: a,   cp: m1, to: mid, into: &segments, depth: depth + 1)
    flattenQuad(from: mid, cp: m2, to: b,   into: &segments, depth: depth + 1)
}

private func flattenCubic(from a: CGPoint, c1: CGPoint, c2: CGPoint, to b: CGPoint,
                          into segments: inout [(CGPoint, CGPoint)],
                          depth: Int = 0) {
    let dx     = b.x - a.x
    let dy     = b.y - a.y
    let cross  = b.x * a.y - b.y * a.x
    let d1     = abs(dy * c1.x - dx * c1.y + cross)
    let d2     = abs(dy * c2.x - dx * c2.y + cross)
    let chord2 = dx * dx + dy * dy
    if depth >= flattenMaxDepth || (d1 + d2) * (d1 + d2) < chord2 * flattenToleranceSqPx {
        segments.append((a, b))
        return
    }
    let m1  = midpoint(a,  c1)
    let m2  = midpoint(c1, c2)
    let m3  = midpoint(c2, b)
    let m12 = midpoint(m1, m2)
    let m23 = midpoint(m2, m3)
    let mid = midpoint(m12, m23)
    flattenCubic(from: a,   c1: m1,  c2: m12, to: mid, into: &segments, depth: depth + 1)
    flattenCubic(from: mid, c1: m23, c2: m3,  to: b,   into: &segments, depth: depth + 1)
}

private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
    CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
}

#Preview {
    VStack(spacing: 20) {
        // Filled — single-layer symbol, comes out as a clean silhouette.
        SFSymbolShape(systemName: "location.fill")
            .fill(.pink)
            .frame(width: 120, height: 120)

        // Stroked + rotated, weight bumped to bold so the outline is
        // clearly different from the regular version.
        SFSymbolShape(systemName: "star.fill",
                      weight:    .bold,
                      rotation:  .degrees(20))
            .stroke(.yellow, lineWidth: 2)
            .frame(width: 120, height: 120)

        // Moon — verifying the resolver handles symbols with a slight
        // inner curve cleanly.
        SFSymbolShape(systemName: "moon.fill")
            .fill(.gray)
            .frame(width: 120, height: 120)
    }
    .padding()
}

#endif
