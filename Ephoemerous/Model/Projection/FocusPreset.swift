import SwiftUI
import CoreGraphics

// MARK: - FocusPreset
// The three tracking modes the user can lock onto.
// Scale and offset are computed dynamically by the tracking methods
// rather than being hardcoded here.
enum FocusPreset: String, CaseIterable, Identifiable {
    case sun  = "trackSun"
    case moon = "trackMoon"
    case star = "trackStar"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sun:  return Strings.Preset.trackSun
        case .moon: return Strings.Preset.trackMoon
        case .star: return Strings.Preset.trackStar
        }
    }

    var symbol: String {
        switch self {
        case .sun:  return "scope"
        case .moon: return "moon.circle"
        case .star: return "star.circle"
        }
    }
}

// MARK: - Preset animation state
// Shared by both FocusPreset tracking transitions and the manual resetView animation.
struct EPresetTransition {
    let fromScale:  Double
    let fromOffset: CGPoint
    let toScale:    Double
    let toOffset:   CGPoint
    let startTime:  Double      // animationTime at start
    let duration:   Double

    // Bounce easing — overshoot then settle
    static func bounceEase(_ t: Double) -> Double {
        let t = max(0, min(1, t))
        return t < 0.5
            ? 4 * t * t * t
            : 1 - pow(-2 * t + 2, 3) / 2 + 0.08 * sin(t * .pi * 2.5) * (1 - t)
    }

    func interpolatedScale(at time: Double) -> Double {
        let t = Self.bounceEase((time - startTime) / duration)
        return fromScale + (toScale - fromScale) * t
    }

    func interpolatedOffset(at time: Double) -> CGPoint {
        let t = Self.bounceEase((time - startTime) / duration)
        return CGPoint(
            x: fromOffset.x + (toOffset.x - fromOffset.x) * t,
            y: fromOffset.y + (toOffset.y - fromOffset.y) * t
        )
    }

    func isFinished(at time: Double) -> Bool {
        time >= startTime + duration
    }
}

// MARK: - EAppState: rendered scale / offset
extension EAppState {

    /// The running transition, if any. Canvas reads this every frame.
    var activeTransition: EPresetTransition? {
        get { _activeTransition }
        set { _activeTransition = newValue }
    }

    /// Use this in EGraphicContext instead of `.scale` directly.
    var renderedScale: Double {
        guard let t = _activeTransition else { return scale }
        if t.isFinished(at: animationTime) {
            _activeTransition = nil
            return scale
        }
        return t.interpolatedScale(at: animationTime)
    }

    /// Use this in EGraphicContext instead of `.offset` directly.
    var renderedOffset: CGPoint {
        guard let t = _activeTransition else { return offset }
        if t.isFinished(at: animationTime) {
            _activeTransition = nil
            return offset
        }
        return t.interpolatedOffset(at: animationTime)
    }

    /// Animate the view back to the default scale and offset.
    func resetView() {
        let toScale  = defaultScale
        let toOffset = defaultOffset
        _activeTransition = EPresetTransition(
            fromScale:  renderedScale,
            fromOffset: renderedOffset,
            toScale:    toScale,
            toOffset:   toOffset,
            startTime:  Date.now.timeIntervalSinceReferenceDate,
            duration:   AstroConstants.transitionDuration
        )
        scale  = toScale
        offset = toOffset
    }

    /// Apply a focus preset, optionally providing the target star for `.star` tracking.
    func apply(_ preset: FocusPreset, star: EStar? = nil) {
        switch preset {
        case .sun:  applySunTracking()
        case .moon: applyMoonTracking()
        case .star: if let star { applyStarTracking(star) }
        }
    }
}

// MARK: - EAppState: Object tracking
extension EAppState {

    /// Centre the viewport on a screen point and zoom to tracking scale,
    /// animated through an EPresetTransition. Shared by sun / moon / star —
    /// previously this body was copy-pasted three times.
    private func beginTracking(toward screenPosition: CGPoint) {
        let targetX   = canvasSize.width  / 2
        let targetY   = canvasSize.height / 2 - 160
        let newOffset = offsetToCenter(screenPos: screenPosition,
                                       atScale:   trackingScale,
                                       targetX:   targetX,
                                       targetY:   targetY)
        _activeTransition = EPresetTransition(
            fromScale:  renderedScale,
            fromOffset: renderedOffset,
            toScale:    trackingScale,
            toOffset:   newOffset,
            startTime:  Date.now.timeIntervalSinceReferenceDate,
            duration:   AstroConstants.transitionDuration
        )
        scale  = trackingScale
        offset = newOffset
    }

    func applySunTracking() {
        guard let sun = sunScreenPosition else {
            ELogger.sun("trackSun: sunScreenPosition not yet available")
            return
        }
        beginTracking(toward: sun)
        ELogger.sun("trackSun: offset → \(offset)")
    }

    func applyMoonTracking() {
        guard let moon = moonScreenPosition else {
            ELogger.moon("trackMoon: moonScreenPosition not yet available")
            return
        }
        beginTracking(toward: moon)
        ELogger.moon("trackMoon: offset → \(offset)")
    }

    func applyStarTracking(_ star: EStar) {
        guard let position = favouritePositions[ESkyObject.star(star).id] ?? screenPosition(of: star) else {
            ELogger.favourites("trackStar: could not compute position for \(star.name)")
            return
        }
        beginTracking(toward: position)
        ELogger.favourites("trackStar: \(star.name) → \(offset)")
    }
}

// MARK: - EAppState: Screen position helper
extension EAppState {

    /// Computes the screen position of a star without relying on the cached favouritePositions.
    func screenPosition(of star: EStar) -> CGPoint? {
        guard canvasSize != .zero else { return nil }
        let (pRA, pDec) = EPrecession.precess(
            ra:  star.rightAscension,
            dec: star.declination,
            to:  renderedObservationDate
        )
        let th = localSiderealOffset.radians
        let (c, s) = (cos(th), sin(th))
        let v = EPrecession.equatorialVector(ra: pRA, dec: pDec)
        let Q = SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
        guard let proj = EProjection.project(Q, viewpoint: self.viewpoint) else { return nil }
        let sx = canvasSize.width  / 2 + proj.x * renderedScale + renderedOffset.y
        let sy = canvasSize.height / 2 - proj.y * renderedScale + renderedOffset.x
        return CGPoint(x: sx, y: sy)
    }

    /// Compute the offset needed to place `screenPos` (computed at the current scale)
    /// at `(targetX, targetY)` after zooming to `newScale`.
    /// Inverts the screen projection to get scale-independent coordinates, then reprojects.
    func offsetToCenter(screenPos: CGPoint, atScale newScale: Double,
                        targetX: Double, targetY: Double) -> CGPoint {
        let s = renderedScale
        let o = renderedOffset
        let projX = (screenPos.x - canvasSize.width  / 2 - o.y) / s
        let projY = (canvasSize.height / 2 - screenPos.y + o.x) / s
        return CGPoint(
            x: targetY - canvasSize.height / 2 + projY * newScale,
            y: targetX - canvasSize.width  / 2 - projX * newScale
        )
    }
}

// EOriginTransition and animateOrigin moved to EAppState+Location.swift.

// `EInertiaTransition` was generalised and is now `LoreKit.FlingInertia`
// (exponential-decay momentum, no app coupling). The gesture-side wiring
// that emits one on pan release lives in CelestialGestureCoordinator+Inertia.
