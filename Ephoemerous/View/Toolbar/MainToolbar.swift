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
            if state.isShowingLocationPicker {
                LocationPickerPanel()
                    .transition(.move(edge: .bottom)
                        .combined(with: .opacity)
                        .combined(with: .blurReplace)
                        .combined(with: .scale))
            }

            if state.isShowingDatePicker {
                DatePickerPanel()
                    .transition(.move(edge: .bottom)
                        .combined(with: .opacity)
                        .combined(with: .blurReplace)
                        .combined(with: .scale))
            }

            GlassEffectContainer {
                HStack(spacing: 0) {
                    locationButton
                        .padding(.horizontal, 0)
//                        .padding(.vertical,   8)
                        .glassEffect(.clear.interactive(),
                                     in: .capsule)
                    Spacer()
                    dateButton
                        .padding(.horizontal, 0)
//                        .padding(.vertical,   8)
                        .glassEffect(.clear.interactive(),
                                     in: .capsule)
                }
            }
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
                Image(systemName: state.isShowingLocationPicker
                      ? "xmark"
                      : "location.fill")
                    .font(.headline)
                if !state.isShowingLocationPicker {
                    Text(locationLabel)
                        .font(.callout.weight(.medium))
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

    private var dateButton: some View {
        Button(action: state.toggleDatePicker) {
            HStack(spacing: 6) {
                Image(systemName: state.isShowingDatePicker
                      ? "xmark"
                      : "calendar")
                    .font(.headline)
                if !state.isShowingDatePicker {
                    Text(dateLabel)
                        .font(.callout.weight(.medium))
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

    /// Locality name if we've got one, else "lat°/lon°" as a fallback.
    /// The name is async-resolved via `refreshLocalityName()` and
    /// driven off `localityKey` below.
    private var locationLabel: String {
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

    /// Three tiers, from terse to verbose:
    ///   • today               → "HH:mm"
    ///   • same year, other day → "d MMM HH:mm"
    ///   • other year          → "d MMM yyyy HH:mm"
    /// The year only appears once it's actually different from the
    /// current one, so the pill stays compact for the common case.
    private var dateLabel: String {
        let cal  = Calendar.current
        let date = state.observationDate
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
