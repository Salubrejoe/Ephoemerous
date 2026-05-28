import SwiftUI
import LoreKit

// MARK: - MainToolbar
// Bottom-of-canvas glass capsule. Two pill-shaped buttons — one for
// observation date, one for observer location — each toggling an
// inline panel that springs up from above the bar.
//
// The toolbar itself never holds the picker UI. State for each panel
// lives on `EAppState` (`isShowingDatePicker` / `isShowingLocationPicker`)
// so other entry points (gestures, deep links, etc.) can open them too,
// and so the two panels stay mutually exclusive via the toggle helpers
// in `EAppState+Time.swift` / `EAppState+Location.swift`.
struct MainToolbar: View {

    @Environment(EAppState.self) private var state

    var body: some View {
        VStack(spacing: 12) {
            // Inline expandable panels live above the toolbar. Both
            // animate in/out via the same transition so the toolbar
            // feels like a single coherent surface.

            GlassEffectContainer {
                HStack(spacing: 0) {
                    
                    locationButton
                    Divider()
                        .padding(.vertical, 8)
                    dateButton
                }
                .frame(height: 32)
                .glassEffect(.clear.interactive(),
                             in: .capsule)
                if state.isShowingLocationPicker {
                    LocationPickerPanel()
                        .transition(.move(edge: .top)
                            .combined(with: .opacity)
                            .combined(with: .blurReplace)
                            .combined(with: .scale))
                }
                
                if state.isShowingDatePicker {
                    DatePickerPanel()
                        .transition(.move(edge: .top)
                            .combined(with: .opacity)
                            .combined(with: .blurReplace)
                            .combined(with: .scale))
                }
            }
            
//            SearchBar()
        }
        .animation(.easeInOut(duration: 0.25), value: state.isShowingDatePicker)
        .animation(.easeInOut(duration: 0.25), value: state.isShowingLocationPicker)
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

    // MARK: - Pills

    private var locationButton: some View {
        Button(action: state.toggleLocationPicker) {
            HStack(spacing: 6) {
                if state.isShowingLocationPicker {
                    Image(symbol: .xmark)
                        .font(.callout)
                        
                        .contentTransition(.symbolEffect(.replace))
                }
                if !state.isShowingLocationPicker {
                    Text(locationLabel)
                        .font(.callout.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .transition(.move(edge: .leading)
                            .combined(with: .opacity)
                            .combined(with: .blurReplace))
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical,    8)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var dateButton: some View {
        Button(action: state.toggleDatePicker) {
            HStack(spacing: 6) {
                if state.isShowingDatePicker {
                    
                    Image(systemName: "xmark")
                        .font(.headline)
                }
                if !state.isShowingDatePicker {
                    Text(dateLabel)
                        .font(.callout.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .transition(.move(edge: .leading)
                            .combined(with: .opacity)
                            .combined(with: .blurReplace))
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical,    8)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pill labels

    /// Three-state SF Symbol for the location pill:
    ///   • `xmark`         — picker is open (tap closes it)
    ///   • `location.fill` — observer is at the device's current location
    ///   • `location`      — observer has been moved elsewhere
    /// Driven through `.contentTransition(.symbolEffect(.replace))`
    /// so swaps animate.
    private var locationButtonSymbol: String {
        if state.isShowingLocationPicker { return "xmark" }
        return state.isAtDeviceLocation ? "location.fill" : "location"
    }

    /// Locality label, three tiers from terse to verbose:
    ///   • observer is at the device's current fix → "Here"
    ///   • locality name resolved by the geocoder   → that name
    ///   • neither                                  → "lat°/lon°"
    /// The "Here" override mirrors the date pill's "Now" — when the
    /// observation matches the device's real-world state right now,
    /// the pill says so directly instead of repeating the resolved
    /// city name.
    private var locationLabel: String {
        if state.isAtDeviceLocation { return "Here" }
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
        if abs(date.timeIntervalSinceNow) < 60 { return "Now" }

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
