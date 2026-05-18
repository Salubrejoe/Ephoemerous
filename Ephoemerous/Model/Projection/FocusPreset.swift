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

// MARK: - EAppState: Sun tracking
extension EAppState {

    func applySunTracking() {
        guard let sun = sunScreenPosition else {
            ELogger.sun("trackSun: sunScreenPosition not yet available")
            return
        }
        let targetScreenX = canvasSize.width  / 2
        let targetScreenY = canvasSize.height / 2 - 160
        let newOffset = offsetToCenter(screenPos: sun, atScale: trackingScale,
                                       targetX: targetScreenX, targetY: targetScreenY)
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
        ELogger.sun("trackSun: offset → \(newOffset)")
    }
}

// MARK: - EAppState: Moon tracking
extension EAppState {

    func applyMoonTracking() {
        guard let moon = moonScreenPosition else {
            ELogger.moon("trackMoon: moonScreenPosition not yet available")
            return
        }
        let targetScreenX = canvasSize.width  / 2
        let targetScreenY = canvasSize.height / 2 - 160
        let newOffset = offsetToCenter(screenPos: moon, atScale: trackingScale,
                                        targetX: targetScreenX, targetY: targetScreenY)
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
        ELogger.moon("trackMoon: offset → \(newOffset)")
    }
}

// MARK: - EAppState: Star tracking
extension EAppState {

    func applyStarTracking(_ star: EStar) {
        let pt: CGPoint
        if let cached = selectedStarPositions[star.name] {
            pt = cached
        } else if let computed = screenPosition(of: star) {
            pt = computed
        } else {
            ELogger.selectedStars("trackStar: could not compute position for \(star.name)")
            return
        }
        let targetScreenX = canvasSize.width  / 2
        let targetScreenY = canvasSize.height / 2 - 160
        let newOffset = offsetToCenter(screenPos: pt, atScale: trackingScale,
                                        targetX: targetScreenX, targetY: targetScreenY)
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
        ELogger.selectedStars("trackStar: \(star.name) → \(newOffset)")
    }
}

// MARK: - EAppState: Screen position helper
extension EAppState {

    /// Computes the screen position of a star without relying on the cached selectedStarPositions.
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
        guard let proj = EProjection.project(Q, appState: self, mode: .northSouth) else { return nil }
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

// MARK: - Origin transition
struct EOriginTransition {
    let fromLat:   Double
    let fromLon:   Double
    let toLat:     Double
    let toLon:     Double
    let startTime: Double
    let duration:  Double

    private static func smoothStep(_ t: Double) -> Double {
        let t = max(0, min(1, t))
        return t * t * (3 - 2 * t)
    }

    func interpolated(at time: Double) -> (lat: Double, lon: Double) {
        let t = Self.smoothStep((time - startTime) / duration)
        return (fromLat + (toLat - fromLat) * t, fromLon + (toLon - fromLon) * t)
    }

    func isFinished(at time: Double) -> Bool { time >= startTime + duration }
}

extension EAppState {

    func animateOrigin(to lat: Angle, lon: Angle, duration: Double = 0.6) {
        _originTransition = EOriginTransition(
            fromLat:   origin.latitude.radians,
            fromLon:   origin.longitude.radians,
            toLat:     lat.radians,
            toLon:     lon.radians,
            startTime: Date.now.timeIntervalSinceReferenceDate,
            duration:  duration
        )
    }
}

// MARK: - Inertia transition
// Momentum glide after a flick. Velocity decays exponentially:
//   v(t) = v0 · e^(−k·t)
// Each frame emits the *exact* integral of v over the elapsed slice, so the
// distance travelled is identical no matter the frame rate (the old version
// multiplied by a hardcoded 1/60 and ended on the first tick — that was the
// "unnaturally sped / instantly dead" inertia).
struct EInertiaTransition {
    let velX:      Double      // pt/s along offset.x  (follows translation.height)
    let velY:      Double      // pt/s along offset.y  (follows translation.width)
    let startTime: Double
    var lastEmittedTime: Double

    /// Decay rate (1/s). Higher = shorter, snappier glide. Total travel ≈ v0 / k.
    let decayRate:         Double = 80.0
    /// Stop once speed has fallen to this fraction of the launch speed.
    let stopSpeedFraction: Double = 0.02

    /// Returns the offset delta to apply for the slice
    /// [lastEmittedTime, time] and whether the glide has settled.
    /// `advance` is mutating: it remembers how far it has already emitted.
    mutating func advance(to time: Double) -> (dx: Double, dy: Double, isFinished: Bool) {
        let k  = decayRate
        let t0 = max(0, lastEmittedTime - startTime)
        let t1 = max(t0, time - startTime)
        // ∫ v0·e^(−k·t) dt  from t0 to t1  =  (v0/k)·(e^(−k·t0) − e^(−k·t1))
        let span = (exp(-k * t0) - exp(-k * t1)) / k
        lastEmittedTime = time
        let finished = exp(-k * t1) < stopSpeedFraction
        return (velX * span, velY * span, finished)
    }
}
