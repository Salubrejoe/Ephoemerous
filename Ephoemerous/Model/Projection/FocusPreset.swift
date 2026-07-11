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
        // Heading-up: return the per-frame-smoothed heading. The low-pass is
        // integrated once per frame in `advanceCanvasClock`, NOT here — this
        // getter MUST be a pure read. The rose dial reads `renderedRotation`
        // several times in one body (alignment test, central letter, orbiting
        // dot) AND reads `_rotationTransition`; a getter that mutated observed
        // state mid-read would make that body an AttributeGraph cycle →
        // main-thread abort. We still touch `aim` so heading changes
        // invalidate the readers, and fall back to the raw heading on the
        // very first frame before the smoother is seeded.
        if compassMode {
            let live = EMotionService.shared.aim
            if let smoothed = _compassRotCurrent { return .radians(smoothed) }
            if let live { return .radians(-live.azimuth) }
        }
        // Pure read: return the interpolated spin, or the committed value once
        // finished. The finished transition is retired in `advanceCanvasClock`.
        guard let t = _rotationTransition else { return canvasRotation }
        if t.isFinished(at: animationTime) { return canvasRotation }
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

    // Heading-up framing tunables (fractions of canvas height). The puck
    // (zenith) drops low so the sky fans up in front of you; the horizon
    // arc lifts toward the top edge — the AR "looking up & forward" pose.
    // ▼ TWEAK HERE ▼
    private var compassPuckYFraction:    Double { 0.82 }   // puck near the bottom
    private var compassHorizonYFraction: Double { 0.08 }   // horizon near the top

    /// Scale + offset for the heading-up pose. The horizon is a circle of
    /// radius 2 projection-units about the zenith (see `EProjection`), so
    /// the zenith→horizon span on screen is `2·scale` — solve that to land
    /// the horizon at `compassHorizonYFraction` while the puck sits at
    /// `compassPuckYFraction`. `offset.x` drives the vertical placement
    /// (see `toScreenPoint`); `offset.y` stays 0 to keep the puck centred.
    var compassFraming: (scale: Double, offset: CGPoint) {
        let h = canvasSize.height
        guard h > 0 else { return (defaultScale, defaultOffset) }
        let puckY    = compassPuckYFraction    * h
        let horizonY = compassHorizonYFraction * h
        let scale    = Swift.max(defaultScale, (puckY - horizonY) / 2)
        return (scale, CGPoint(x: puckY - h / 2, y: 0))
    }

    /// Framing for compass mode on the SkyLab `SkyCamera` (the live main
    /// view). Same AR pose as `compassFraming`, expressed in that camera's
    /// terms: `SkyCamera.screen(.zero)` puts the zenith at
    /// `screenCentre + offset`, and the horizon is a circle of radius 2
    /// projection-units about the zenith — so on screen the zenith→horizon
    /// span is `2·scale`.
    ///
    /// The puck (zenith) drops to `compassPuckYFraction` of the SCREEN
    /// height (just above the bottom sheet); the facing horizon rises to
    /// `compassHorizonYFraction` (just below the Here/Now capsules). Pass the
    /// visible screen height (`geo.size.height`), NOT the oversized canvas —
    /// the fractions are screen-relative.
    func compassCameraFraming(screenHeight h: CGFloat) -> (scale: CGFloat, offset: CGSize) {
        guard h > 0 else { return (defaultScale, .zero) }
        let puckY    = compassPuckYFraction    * h
        let horizonY = compassHorizonYFraction * h
        let scale    = Swift.max(defaultScale, (puckY - horizonY) / 2)
        // offset.height positions the zenith below screen centre; offset.width
        // stays 0 to keep the puck horizontally centred.
        return (scale, CGSize(width: 0, height: puckY - h / 2))
    }

    /// Engage heading-up mode and frame the sky for it (puck low, horizon
    /// up). Assumes the observer is already at the device location — the
    /// toggle / auto-engage callers gate that (and prompt) themselves.
    func engageCompassMode() {
        // SkyLab owns the camera; just flip the flag — the heading drives
        // the rotation. The old AR framing (compassFraming + animateTo)
        // moved the production camera the SkyLab ignores, so it's dropped.
        _rotationTransition = nil
        // Compass is intrinsically zenith/AR — drop the inside-out flip so
        // the two never fight over the projection centre.
        flippedProjection = false
        compassMode = true
    }

    /// Leave heading-up mode: freeze the live heading into `canvasRotation`
    /// so nothing jumps, then zoom back to the default centred view.
    func disengageCompassMode() {
        let frozen = renderedRotation     // current heading rotation
        compassMode = false
        _rotationTransition = nil
        canvasRotation = frozen
//        resetView()
    }

    /// Flip heading-up mode on or off (the toolbar toggle).
    ///
    /// • ON, at Here — engage + frame immediately.
    /// • ON, away from Here — compass mode orients from where you actually
    ///   stand, so we must snap the observer back to Here first. Rather than
    ///   do that silently, raise the `_compassReturnHomePrompt` confirmation;
    ///   `confirmReturnHomeAndEngageCompass()` does the recenter + engage.
    /// • OFF — freeze the heading and restore the pre-compass framing.
    func toggleCompassMode() {
        if compassMode {
            disengageCompassMode()
        } else if isAtDeviceLocation {
            engageCompassMode()
        } else {
            _compassReturnHomePrompt = true
        }
    }

    /// User accepted the return-to-Here prompt: recenter on the device
    /// location, then engage heading-up.
    func confirmReturnHomeAndEngageCompass() {
        _compassReturnHomePrompt = false
        goToDeviceLocation()
        engageCompassMode()
    }

    /// Spring the canvas back to North, leaving compass mode if it was on.
    /// Captures the live heading rotation BEFORE clearing the flag so the
    /// spin-back starts from where the sky actually is (not a stale
    /// `canvasRotation`) — otherwise it would snap. Also zooms back to the
    /// default view when it was a heading-up exit.
    func resetRotationToNorth() {
        let current = renderedRotation
        compassMode = false
        canvasRotation = current
        animateRotation(to: .zero)
        // (resetView dropped — it zoomed the production camera the SkyLab
        //  ignores; the rose's job here is purely the spin to north.)
    }
}

// MARK: - EAppState: rendered scale / offset
extension EAppState {

    /// The running transition, if any. Canvas reads this every frame.
    var activeTransition: EPresetTransition? {
        get { _activeTransition }
        set { _activeTransition = newValue }
    }

    /// Use this in EGraphicContext instead of `.scale` directly. PURE read —
    /// the finished transition is retired in `advanceCanvasClock`, not here,
    /// so a view body that reads both `renderedScale` and `_activeTransition`
    /// (e.g. the canvas via `isAnimating`) can't trip an AttributeGraph cycle.
    var renderedScale: Double {
        guard let t = _activeTransition else { return scale }
        return t.isFinished(at: animationTime) ? scale
                                               : t.interpolatedScale(at: animationTime)
    }

    /// Use this in EGraphicContext instead of `.offset` directly. PURE read
    /// (see `renderedScale`).
    var renderedOffset: CGPoint {
        guard let t = _activeTransition else { return offset }
        return t.isFinished(at: animationTime) ? offset
                                               : t.interpolatedOffset(at: animationTime)
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
