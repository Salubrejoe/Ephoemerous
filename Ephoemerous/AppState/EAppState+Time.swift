import Foundation

// MARK: - EDateTransition
// Describes a smooth animated jump between two observation dates.
// Canvas layers read `renderedObservationDate` instead of `observationDate` directly
// so that in-flight animations are reflected in the projection.
struct EDateTransition {
    let fromInterval: TimeInterval
    let toInterval:   TimeInterval
    let startTime:    Double        // wall-clock seconds since reference date
    let duration:     Double        // animation length in seconds

    /// Smooth-stepped interpolated date at a given animation time.
    func interpolated(at time: Double) -> Date {
        let raw = (time - startTime) / duration
        let t   = max(0, min(1, raw))
        let st  = t * t * (3 - 2 * t)      // smooth step — no overshoot, sky rotation looks odd with bounce
        return Date(timeIntervalSinceReferenceDate: fromInterval + (toInterval - fromInterval) * st)
    }

    func isFinished(at time: Double) -> Bool {
        time >= startTime + duration
    }
}

// MARK: - EAppState + Time
extension EAppState {

    /// The date every canvas layer should use for rendering.
    /// Returns the animated intermediate date while a transition is in flight,
    /// falling back to `observationDate` once it completes.
    var renderedObservationDate: Date {
        guard let t = _dateTransition else { return observationDate }
        if t.isFinished(at: animationTime) {
            _dateTransition = nil
            return observationDate
        }
        return t.interpolated(at: animationTime)
    }

    /// Set the observation date, optionally animating the sky rotation.
    /// Always call this instead of assigning `observationDate` directly when animation is desired.
    func setObservationDate(_ newDate: Date, animated: Bool = true) {
        guard animated else { observationDate = newDate; return }
        _dateTransition = EDateTransition(
            fromInterval: renderedObservationDate.timeIntervalSinceReferenceDate,
            toInterval:   newDate.timeIntervalSinceReferenceDate,
            startTime:    Date.now.timeIntervalSinceReferenceDate,
            duration:     0.7
        )
        observationDate = newDate
    }

    /// Commit a date chosen in the date picker.
    /// A same-day edit (time only) animates the sky; a day change jumps
    /// (a large rotation looks wrong animated). Either way the projection is
    /// coupled for the move and then restored — the previous code only
    /// restored on the time-only path, stranding day changes in `.coupled`.
    func commitPickedObservationDate(_ newDate: Date) {
        let sameDay = Calendar.current.isDate(observationDate, inSameDayAs: newDate)
        if sameDay {
            setObservationDate(newDate)
        } else {
            _dateTransition = nil
            observationDate = newDate
        }
    }

    /// Show or hide the inline date picker. Opening it first resets the
    /// viewport so the picker isn't fighting a tracking transition.
    func toggleDatePicker() {
        if !isShowingDatePicker { resetView() }
        isShowingDatePicker.toggle()
    }

    /// Whether the observation date falls on the current calendar day.
    var isObservationDateToday: Bool {
        Calendar.current.isDateInToday(observationDate)
    }

    /// True when the observation date differs from "now" at minute resolution.
    /// Drives the visibility of the reset-to-now control.
    var observationDiffersFromNow: Bool {
        guard isObservationDateToday else { return true }
        let calendar = Calendar.current
        let now      = Date.now
        return calendar.component(.hour,   from: observationDate) != calendar.component(.hour,   from: now)
            || calendar.component(.minute, from: observationDate) != calendar.component(.minute, from: now)
    }
}
