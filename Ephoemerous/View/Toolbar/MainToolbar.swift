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
                    .padding(.horizontal, 8)
                    .transition(.move(edge: .bottom)
                        .combined(with: .opacity)
                        .combined(with: .blurReplace))
            }

            if state.isShowingDatePicker {
                DatePickerPanel()
                    .padding(.horizontal, 8)
                    .transition(.move(edge: .bottom)
                        .combined(with: .opacity)
                        .combined(with: .blurReplace))
            }

            GlassEffectContainer {
                HStack(spacing: 8) {
                    locationButton
                    dateButton
                }
                .padding(.horizontal, 8)
                .padding(.vertical,   8)
                .glassEffect(.clear.interactive(),
                             in: RoundedRectangle(cornerRadius: 28,
                                                  style: .continuous))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: state.isShowingDatePicker)
        .animation(.easeInOut(duration: 0.25), value: state.isShowingLocationPicker)
    }

    // MARK: - Pills

    private var locationButton: some View {
        Button(action: state.toggleLocationPicker) {
            HStack(spacing: 6) {
                Image(systemName: state.isShowingLocationPicker
                      ? "xmark"
                      : "location.fill")
                    .font(.callout)
                Text(locationLabel)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical,    8)
            .frame(maxWidth: .infinity)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.clear.interactive(), in: .capsule)
    }

    private var dateButton: some View {
        Button(action: state.toggleDatePicker) {
            HStack(spacing: 6) {
                Image(systemName: state.isShowingDatePicker
                      ? "xmark"
                      : "calendar")
                    .font(.callout)
                Text(dateLabel)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical,    8)
            .frame(maxWidth: .infinity)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.clear.interactive(), in: .capsule)
    }

    // MARK: - Pill labels

    private var locationLabel: String {
        let lat = state.origin.latitude.degrees
        let lon = state.origin.longitude.degrees
        let latStr = String(format: "%.1f°%@", abs(lat), lat >= 0 ? "N" : "S")
        let lonStr = String(format: "%.1f°%@", abs(lon), lon >= 0 ? "E" : "W")
        return "\(latStr)  \(lonStr)"
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = Calendar.current.isDateInToday(state.observationDate)
            ? "HH:mm"           // today → just the time
            : "d MMM HH:mm"     // other day → date + time
        return f.string(from: state.observationDate)
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
