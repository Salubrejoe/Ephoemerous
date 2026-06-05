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

// MARK: - Rotation animation state
// Single-angle sibling of EPresetTransition, for the compass spin-back.
// Reuses the same bounce easing so the needle (and sky) overshoot North
// slightly then settle.
struct ERotationTransition {
    let from:      Angle
    let to:        Angle
    let startTime: Double
    let duration:  Double

    func interpolated(at time: Double) -> Angle {
        let t = EPresetTransition.bounceEase((time - startTime) / duration)
        return .degrees(from.degrees + (to.degrees - from.degrees) * t)
    }

    func isFinished(at time: Double) -> Bool {
        time >= startTime + duration
    }
}

// MARK: - EAppState: rendered scale / offset
extension EAppState {

    /// Canvas-facing rotation. Returns the bouncy interpolation while a
    /// reset spin is in flight, otherwise the live `canvasRotation`. Nils
    /// the finished transition in place — same lazy pattern as
    /// `renderedScale`. The Canvas snapshot AND the compass dial both read
    /// this, so they animate together.
    var renderedRotation: Angle {
        // Compass (heading-up) mode wins: spin the map so the phone's
        // heading sits at the top, leaving the aim cone fixed pointing up.
        // Azimuth is CW+ from north; the canvas rotation is CCW+ (toScreen
        // flips Y), so negate. Reading `aim` here makes the canvas + the
        // compass rose repaint on every heading change — the same hook the
        // cone uses — so the rotation tracks the phone with no tick driver.
        if compassMode, let aim = EMotionService.shared.aim {
            return .radians(-aim.azimuth)
        }
        guard let t = _rotationTransition else { return canvasRotation }
        if t.isFinished(at: animationTime) {
            _rotationTransition = nil
            return canvasRotation
        }
        return t.interpolated(at: animationTime)
    }

    /// Animate the canvas spin to `target` with a settling overshoot.
    /// Commits `canvasRotation` to the target immediately (so all the
    /// gesture math reads the final value) while the transition drives the
    /// visible interpolation.
    func animateRotation(to target: Angle) {
        _rotationTransition = ERotationTransition(
            from:      renderedRotation,
            // Wall-clock now, NOT `animationTime` — the canvas is parked
            // (idle) by the time the compass is tapped, so `animationTime`
            // is frozen at the last pre-park tick. Seeding the transition
            // from that stale value makes the first restarted frame read
            // elapsed > duration and finish instantly (a snap). Mirror
            // `animateTo`, which seeds from `Date.now` for this reason.
            to:        target,
            startTime: Date.now.timeIntervalSinceReferenceDate,
            duration:  AstroConstants.transitionDuration
        )
        canvasRotation = target
    }

    // MARK: - Compass (heading-up) mode

    /// Flip heading-up mode on or off.
    ///
    /// • ON — if the observer has panned away from the device location,
    ///   recenter there first (compass mode is about orienting from where
    ///   you actually stand), drop any in-flight spin-back, then engage:
    ///   `renderedRotation` starts following the heading immediately.
    /// • OFF — freeze the map exactly where the heading left it (commit the
    ///   live heading rotation into `canvasRotation`) so nothing jumps.
    func toggleCompassMode() {
        if compassMode {
            let frozen = renderedRotation     // current heading rotation
            compassMode = false
            _rotationTransition = nil
            canvasRotation = frozen
        } else {
            if !isAtDeviceLocation { goToDeviceLocation() }
            _rotationTransition = nil
            compassMode = true
        }
    }

    /// Spring the canvas back to North, leaving compass mode if it was on.
    /// Captures the live heading rotation BEFORE clearing the flag so the
    /// spin-back starts from where the sky actually is (not a stale
    /// `canvasRotation`) — otherwise it would snap.
    func resetRotationToNorth() {
        let current = renderedRotation
        compassMode = false
        canvasRotation = current
        animateRotation(to: .zero)
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

    /// THE single camera-animation primitive. Every programmatic camera
    /// move — reset, and centring on an object (`EAppState+Detail`) — goes
    /// through here, so the dedupe and the transition-start logic live in
    /// exactly one place.
    ///
    /// Dedupe: if a transition is already heading to ~this destination,
    /// don't restart its clock — just keep the committed end-state
    /// authoritative. Two call sites aiming at the same place a frame
    /// apart (e.g. a selection's focus-pan + the detail view's onAppear
    /// re-pan) then collapse to one smooth animation instead of two
    /// overlapping eases. A genuinely different target starts a fresh
    /// transition as normal.
    func animateTo(scale newScale: Double, offset newOffset: CGPoint) {
        if let t = _activeTransition,
           abs(t.toScale - newScale)     < 0.5,
           abs(t.toOffset.x - newOffset.x) < 0.5,
           abs(t.toOffset.y - newOffset.y) < 0.5 {
            scale  = newScale
            offset = newOffset
            return
        }
        _activeTransition = EPresetTransition(
            fromScale:  renderedScale,
            fromOffset: renderedOffset,
            toScale:    newScale,
            toOffset:   newOffset,
            startTime:  Date.now.timeIntervalSinceReferenceDate,
            duration:   AstroConstants.transitionDuration
        )
        scale  = newScale
        offset = newOffset
    }

    /// Animate the view back to the default scale and offset.
    func resetView() {
        animateTo(scale: defaultScale, offset: defaultOffset)
    }
}

// MARK: - EAppState: Screen position helpers
extension EAppState {

    /// Project-unit point → screen pixel. Mirror of
    /// `EGraphicContext.toScreen` so callers outside the draw loop
    /// (focus / pan logic) land on the same screen coordinates the
    /// canvas draws to. Applies `canvasRotation` first so off-screen
    /// focus from the search sheet works correctly when the device
    /// is held landscape (sky-fixed rotation in effect).
    func toScreenPoint(_ p: CGPoint) -> CGPoint {
        let pRot: CGPoint
        if canvasRotation == .zero {
            pRot = p
        } else {
            let θ    = canvasRotation.radians
            let cosθ = cos(θ)
            let sinθ = sin(θ)
            pRot = CGPoint(x: p.x * cosθ - p.y * sinθ,
                           y: p.x * sinθ + p.y * cosθ)
        }
        return CGPoint(
            x: canvasSize.width  / 2 + pRot.x * renderedScale + renderedOffset.y,
            y: canvasSize.height / 2 - pRot.y * renderedScale + renderedOffset.x
        )
    }

    /// Computes the screen position of a star without relying on the
    /// cached `favouritePositions`. Used when focusing on a star
    /// that's currently off-screen (e.g. from the search sheet).
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
        return toScreenPoint(proj)
    }

    /// Computes the screen position of a constellation's label
    /// anchor without relying on `constellationLabelHitRects` — the
    /// hit-rect cache only carries entries for constellations
    /// currently rendered at text tier on screen. From the search
    /// sheet the user can pick any constellation regardless of
    /// whether its label is visible right now, so we need to
    /// project from the anchor RA/Dec directly.
    func screenPosition(of constellation: EConstellation) -> CGPoint? {
        guard canvasSize != .zero,
              let anchor = ConstellationLines.shared.labelAnchors[constellation]
        else { return nil }
        let (pRA, pDec) = EPrecession.precess(
            ra:  anchor.ra,
            dec: anchor.dec,
            to:  renderedObservationDate
        )
        let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
            .sidereallyRotated(by: localSiderealOffset)
        guard let proj = EProjection.project(Q, viewpoint: self.viewpoint) else { return nil }
        return toScreenPoint(proj)
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
