import SwiftUI
import CoreGraphics

// MARK: - EViewPreset
struct EViewPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let symbol: String
    let scale: Double
    let offset: CGPoint

    static func == (lhs: EViewPreset, rhs: EViewPreset) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Built-in presets
    static let morningTime = EViewPreset(
        id: "morningTime",
        name: Strings.Preset.morning,
        symbol: "sunrise",
        scale: 90,
        offset: CGPoint(x: 12, y: 155)
    )
    static let daytime = EViewPreset(
        id: "daytime",
        name: Strings.Preset.day,
        symbol: "sun.max",
        scale: 90,
        offset: CGPoint(x: 12, y: 0)
    )
    static let afternoonTime = EViewPreset(
        id: "afternoonTime",
        name: Strings.Preset.afternoon,
        symbol: "sunset",
        scale: 90,
        offset: CGPoint(x: 12, y: -155)
    )
    static let nightTime = EViewPreset(
        id: "nightTime",
        name: Strings.Preset.night,
        symbol: "moon.stars",
        scale: 90,
        offset: CGPoint(x: -50, y: 0)
    )

    static let trackSun = EViewPreset(id: "trackSun", name: Strings.Preset.trackSun, symbol: "scope", scale: 0, offset: .zero)
    static let trackMoon = EViewPreset(id: "trackMoon", name: Strings.Preset.trackMoon, symbol: "moon.circle", scale: 0, offset: .zero)
    static let trackStar = EViewPreset(id: "trackStar", name: Strings.Preset.trackStar, symbol: "star.circle", scale: 0, offset: .zero)
    static let all: [EViewPreset] = [morningTime, daytime, afternoonTime, nightTime, trackSun, trackMoon, trackStar]
}

// MARK: - Preset animation state
struct EPresetTransition {
    let fromScale:  Double
    let fromOffset: CGPoint
    let toScale:    Double
    let toOffset:   CGPoint
    let startTime:  Double      // animationTime at start
    let duration:   Double      // seconds

    // Bounce easing -- overshoot then settle
    static func bounceEase(_ t: Double) -> Double {
        let t = max(0, min(1, t))
        // Approximation of a spring: overshoot ~8% at t=0.6
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

// MARK: - EAppState extension
extension EAppState {

    // The running transition, if any. Canvas reads this every frame.
    var activeTransition: EPresetTransition? {
        get { _activeTransition }
        set { _activeTransition = newValue }
    }

    // Rendered scale -- use this in EGraphicContext instead of .scale
    var renderedScale: Double {
        guard let t = _activeTransition else { return scale }
        if t.isFinished(at: animationTime) {
            _activeTransition = nil
            return scale
        }
        return t.interpolatedScale(at: animationTime)
    }

    // Rendered offset -- use this in EGraphicContext instead of .offset
    var renderedOffset: CGPoint {
        guard let t = _activeTransition else { return offset }
        if t.isFinished(at: animationTime) {
            _activeTransition = nil
            return offset
        }
        return t.interpolatedOffset(at: animationTime)
    }

    var activePreset: EViewPreset? {
        EViewPreset.all.first { 
            abs($0.scale    - scale)      < 0.001 &&
            abs($0.offset.x - offset.x) < 0.001 &&
            abs($0.offset.y - offset.y) < 0.001
        }
    }

    func apply(_ preset: EViewPreset) {
        _activeTransition = EPresetTransition(
            fromScale:  renderedScale,
            fromOffset: renderedOffset,
            toScale:    preset.scale,
            toOffset:   preset.offset,
            startTime:  Date.now.timeIntervalSinceReferenceDate,
            duration:   AstroConstants.transitionDuration
        )
        scale  = preset.scale
        offset = preset.offset
        ELogger.sun("Preset applied: " + preset.name)
    }
}

// MARK: - Sun tracking
extension EAppState {

    // Places the sun at screen centre + 80 pts below (y=80 in offset space).
    // offset.y drives screenX, offset.x drives screenY (see toScreen).
    func applySunTracking() {
        guard let sun = sunScreenPosition else {
            ELogger.sun("trackSun: sunScreenPosition not yet available")
            return
        }
        let targetScreenX = canvasSize.width  / 2
        let targetScreenY = canvasSize.height / 2 - 160
        let newOffset = CGPoint(
            x: offset.x + (targetScreenY - sun.y),
            y: offset.y + (targetScreenX - sun.x)
        )
        _activeTransition = EPresetTransition(
            fromScale:  renderedScale,
            fromOffset: renderedOffset,
            toScale:    scale,
            toOffset:   newOffset,
            startTime:  Date.now.timeIntervalSinceReferenceDate,
            duration:   AstroConstants.transitionDuration
        )
        offset = newOffset
        ELogger.sun("trackSun: offset set to " + newOffset.debugDescription)
    }
}


// MARK: - Time of day preset
extension EAppState {

    // 04:00 - 10:00  morning
    // 10:00 - 14:00  day
    // 14:00 - 20:00  afternoon
    // 20:00 - 04:00  night
    var timeOfDayPreset: EViewPreset {
        let hour = Calendar.current.component(.hour, from: observationDate)
        switch hour {
        case 4..<10:  return .morningTime
        case 10..<14: return .daytime
        case 14..<20: return .afternoonTime
        default:      return .nightTime
        }
    }

    func applyTimeOfDayPreset() {
        let preset = timeOfDayPreset
        guard preset != activePreset else { return }
        apply(preset)
        ELogger.sun("Time-of-day preset: " + preset.name)
    }
}

// MARK: - Moon tracking
extension EAppState {

    func applyMoonTracking() {
        guard let moon = moonScreenPosition else {
            ELogger.moon("trackMoon: moonScreenPosition not yet available")
            return
        }
        let targetScreenX = canvasSize.width  / 2
        let targetScreenY = canvasSize.height / 2 - 160
        let newOffset = CGPoint(
            x: offset.x + (targetScreenY - moon.y),
            y: offset.y + (targetScreenX - moon.x)
        )
        _activeTransition = EPresetTransition(
            fromScale:  renderedScale,
            fromOffset: renderedOffset,
            toScale:    scale,
            toOffset:   newOffset,
            startTime:  Date.now.timeIntervalSinceReferenceDate,
            duration:   AstroConstants.transitionDuration
        )
        offset = newOffset
        ELogger.moon("trackMoon: offset set to " + newOffset.debugDescription)
    }
}

// MARK: - Star tracking
extension EAppState {

    func applyStarTracking(_ star: EStar) {
        guard let pt = selectedStarPositions[star.name] else {
            ELogger.selectedStars("trackStar: no screen position for " + star.name)
            return
        }
        let targetScreenX = canvasSize.width  / 2
        let targetScreenY = canvasSize.height / 2 - 160
        let newOffset = CGPoint(
            x: offset.x + (targetScreenY - pt.y),
            y: offset.y + (targetScreenX - pt.x)
        )
        _activeTransition = EPresetTransition(
            fromScale:  renderedScale,
            fromOffset: renderedOffset,
            toScale:    scale,
            toOffset:   newOffset,
            startTime:  Date.now.timeIntervalSinceReferenceDate,
            duration:   AstroConstants.transitionDuration
        )
        offset = newOffset
        ELogger.selectedStars("trackStar: " + star.name + " -> " + newOffset.debugDescription)
    }
}
