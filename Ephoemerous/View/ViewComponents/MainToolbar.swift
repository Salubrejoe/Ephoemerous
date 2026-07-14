import SwiftUI
import LoreKit


struct MainToolbar: View {

    @Environment(EAppState.self) private var state
    @Environment(\.scenePhase)   private var scenePhase

    /// Bumped on appear and on every scene-becomes-active so the
    /// label computed properties recompute. The Here / Now strings
    /// depend on `Date.now` and the device-location fix — neither is
    /// `@Observable`, so without a tick like this the label can sit
    /// at "Now" forever after the phone has been left on the table
    /// (the body never has any reason to re-evaluate).
    @State private var refreshTick: Int = 0

    /// Morph namespace so the flanking reset chips grow out of / melt back
    /// into the status capsule (Liquid Glass `glassEffectID`).
    @Namespace private var glassNS

    /// Capsule + reset-chip height.
    private let barHeight: CGFloat = 32

    
    
    // MARK: - body
    var body: some View {
        // Reading `refreshTick` here registers the dependency for
        // every label call downstream; bumping the tick re-renders
        // the toolbar and rewalks the dateLabel / locationLabel
        // computed properties.
        let _ = refreshTick
        // Status capsule flanked by two reset chips. The pills show the
        // current value (Here/London, Now/21:40) and raise a bottom-sheet
        // editor; the chips appear OUTSIDE the capsule when the observer
        // has drifted off Here / Now — a one-tap "go back". They morph out
        // of (and melt back into) the capsule via the Liquid Glass
        // container + `glassEffectID`, so they read as growing from its
        // ends. Leading chip ↔ location (Here); trailing chip ↔ date (Now).
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                if notHere {
                    ToolbarResetButton(
                        size:   barHeight,
                        symbol: "location.fill",             // back to HERE
                        action: state.goToDeviceLocation
                    )
                    .glassEffectID("resetHere", in: glassNS)
                    .transition(.offset(x: barHeight).combined(with: .opacity))
                }

                HStack(spacing: 0) {
                    ToolbarPill(
                        locationLabel,
                        action: state.toggleLocationPicker
                    )
                    Divider()
                        .padding(.vertical, 8)
                    ToolbarPill(
                        dateLabel,
                        action: state.toggleDatePicker
                    )
                }
                .frame(height: barHeight)
                .glassEffect(.regular.interactive(), in: .capsule)
                .glassEffectID("bar", in: glassNS)

                if notNow {

                    ToolbarResetButton(
                        size:   barHeight,
                        symbol: "clock.arrow.circlepath",    // back to NOW
                        action: { state.commitPickedObservationDate(.now, ) }
                    )
                    .glassEffectID("resetNow", in: glassNS)
                    .transition(.offset(x: -barHeight).combined(with: .opacity))
                }
            }
        } //: GlassEffectContainer
        
       
        // MARK: - REFRESH HERE/NOW
        
        // Animate the chips growing in / shrinking out as the flags flip.
        .animation(.bouncy, value: notHere)
        .animation(.bouncy, value: notNow)
        
        // Bump the refresh tick on initial appear and every time the
        // scene returns to `.active` (phone woken from sleep, app
        // returning from background). Re-evaluating the body recomputes
        // the dateLabel / locationLabel — and `notNow` — against the
        // current wall-clock and device-location fix.
        .onAppear { refreshTick &+= 1 }
        .onChange(of: scenePhase) { _, new in
            if new == .active { refreshTick &+= 1 }
        }
        
        // Re-resolve the locality name whenever the rounded origin
        // changes. `.task(id:)` cancels and restarts when the id
        // shifts, which gives us a built-in debounce — the 400 ms
        // sleep lets a slerp settle before we hit the geocoder.
        .task(id: localityKey) {
            // Clear the stale name immediately so the pill falls
            // back to coordinates while we wait, then geocode.
            state.localityName = nil
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await state.refreshLocalityName()
        }
    }

    
    
    // MARK: - Reset Conditions

    /// True when the observer has been moved off the device's real fix —
    /// and we actually have a fix to return to — so the leading "back to
    /// Here" chip is worth showing.
    private var notHere: Bool {
        ELocationService.shared.location != nil && !state.isAtDeviceLocation
    }

    /// True when the observation time is more than a minute off real now,
    /// so the trailing "back to Now" chip shows. Same 60 s rule as the
    /// pill's "Now" label and the date picker's Now button.
    private var notNow: Bool {
        abs(state.observationDate.timeIntervalSinceNow) >= 60
    }
}




// MARK: - Pill labels
extension MainToolbar {
    
    /// Locality label, three tiers from terse to verbose:
    ///   • observer is at the device's current fix → "Here"
    ///   • locality name resolved by the geocoder   → that name
    ///   • neither                                  → "lat°/lon°"
    /// The "Here" override mirrors the date pill's "Now" — when the
    /// observation matches the device's real-world state right now,
    /// the pill says so directly instead of repeating the resolved
    /// city name.
    private var locationLabel: String {
        if state.isAtDeviceLocation { return String(localized: "Here") }
        if let name = state.localityName, !name.isEmpty {
            return name
        }
        let lat = state.origin.latitude.degrees
        let lon = state.origin.longitude.degrees
        let latStr = String(format: "%.1f°%@", abs(lat), lat >= 0 ? "N" : "S")
        let lonStr = String(format: "%.1f°%@", abs(lon), lon >= 0 ? "E" : "W")
        return "\(latStr)  \(lonStr)"
    }
    
    /// Stable id for `.task(id:)` — re-fires the geocode only when
    /// the origin shifts by more than 0.1° (~11 km), so a per-frame
    /// slerp doesn't queue up dozens of geocodes.
    private var localityKey: String {
        String(format: "%.1f,%.1f",
               state.origin.latitude.degrees,
               state.origin.longitude.degrees)
    }
    
    /// Four tiers, from terse to verbose:
    ///   • observation within 60 s of real now → "Now"
    ///   • today                               → "HH:mm"
    ///   • same year, other day                → "d MMM HH:mm"
    ///   • other year                          → "d MMM yyyy HH:mm"
    /// The 60-second window matches `DatePickerPanel`'s Now-button
    /// disabled threshold so the pill says "Now" exactly when the
    /// Now button is greyed out.
    private var dateLabel: String {
        let date = state.observationDate
        if abs(date.timeIntervalSinceNow) < 60 { return String(localized: "Now") }
        
        let cal = Calendar.current
        let format: String
        if cal.isDateInToday(date) {
            format = "HH:mm"
        } else if cal.component(.year, from: date)
                    == cal.component(.year, from: .now) {
            format = "d MMM HH:mm"
        } else {
            format = "d MMM yyyy HH:mm"
        }
        let f = DateFormatter()
        f.dateFormat = format
        return f.string(from: date)
    }
}


#Preview {
    ZStack {
        LinearGradient(colors: [.blue, .pink],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        VStack {
            Spacer()
            MainToolbar()
                .padding(.horizontal, 16)
                .padding(.bottom,     12)
        }
    }
    .environment(EAppState())
}
