import SwiftUI
import LoreKit

// MARK: - DatePickerPanel
// The time-travel instrument, FREE-FLOATING — no sheet. Sheets are for
// content; instruments stand on the sky. The crown (`DateCrown`) floats
// above one control row:
//
//     [ Now ]   [ Hours · Days · Months · Years ]   [ ✕ ]
//
// No title (a crown needs no nameplate) and no date readout — the toolbar
// capsule at the top is already the live readout, counting as you scrub.
// The sky all around stays touchable.
//
// The precise five-wheel form survives as the escape hatch behind the
// crown's quiet centre glyph: it unfolds in place of the dial for surgical
// absolute jumps (eclipse day), and the row's dial chip folds it away.
//
// Wheel mechanics (kept from the original panel): each wheel updates one
// calendar component in isolation; month/year changes clamp `day` to the
// new month's max so we never construct an illegal date (e.g. 31 Feb).
struct DatePickerPanel: View {

    @Environment(AppState.self) private var state

    @State private var gear: DateCrown.Gear = .hours
    /// Precise-wheels disclosure — folded by default; the crown's centre
    /// glyph opens it, the row's dial chip closes it.
    @State private var showWheels = false

    private let gearTick = UIImpactFeedbackGenerator(style: .medium)

    /// 200-year span centred on the current year. Covers stargazing
    /// scenarios from historical (e.g. "sky over Paris during the
    /// Revolution") to forward projection ("Mars opposition in 2092").
    private static let yearSpan: Int = 100

    var body: some View {
        ZStack {
            // The ring rests ON the horizon circle (NorthIN) / the tropic
            // (NorthOUT) — same screen radius by construction: the camera
            // glides home on present (see MainView), where the horizon
            // projects at exactly 2 · defaultScale about the screen centre.
            if !showWheels {
                DateCrown(radius: CGFloat(2 * state.defaultScale), gear: $gear)
                    .transition(.opacity)
            }

            VStack(spacing: 16) {
                Spacer()
                if showWheels {
                    preciseWheels
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }
                controlRow
            }
            .padding(.horizontal, 16)
            // Clear the home indicator. ▼ TWEAK the float here ▼
            .padding(.bottom, 48)
        }
        .animation(.snappy(duration: 0.25), value: showWheels)
    }

    // MARK: - Control row

    private var controlRow: some View {
        GlassEffectContainer {
            HStack(spacing: 12) {
                
                if showWheels {
                    // Wheels open → the gears are moot; offer the way back to
                    // the ring instead.
                    Button {
                        gearTick.impactOccurred()
                        showWheels = false
                    } label: {
                        Image(systemName: "dial.low")
                            .font(.system(size: 17, weight: .medium))
                            .frame(width: 44, height: 36)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .capsule)
                } else {
                    
                    
                    // Door to the precise wheels (the ring has no centre to
                    // carry it any more).
                    
                    CircleIconButton(symbol: .calendar) {
                        gearTick.impactOccurred()
                        showWheels = true
                    }
                    
                    gearSegments
                    
                    CircleIconButton(symbol: .xmark) {
                        state.isShowingDatePicker = false
                    }
                }
                
                //            Spacer(minLength: 0)
                //
                //            CircleIconButton(symbol: .xmark) {
                //                state.isShowingDatePicker = false
                //            }
            }
        }
    }

    /// The crown's gear positions as one glass segmented capsule.
    private var gearSegments: some View {
        Picker("", selection: $gear) {
            ForEach(DateCrown.Gear.allCases) { g in
                Text(g.label)
                    .tag(g)
            }
        }
        .pickerStyle(.segmented)
        .frame(height: 44)
        .padding(.horizontal, 6)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    // MARK: - Precise wheels (the escape hatch)

    private var preciseWheels: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                Picker("Day", selection: dayBinding) {
                    ForEach(1...daysInCurrentMonth, id: \.self) { d in
                        Text("\(d)").tag(d)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 55)
                .clipped()

                Picker("Month", selection: monthBinding) {
                    ForEach(1...12, id: \.self) { m in
                        Text(Self.monthName(m)).tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 76)
                .clipped()

                Picker("Year", selection: yearBinding) {
                    ForEach(yearRange, id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
                .pickerStyle(.wheel)
                .clipped()
            }

            Text(",")

            HStack(spacing: 0) {
                Picker("Hour", selection: hourBinding) {
                    ForEach(0...23, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 55)
                .clipped()

                Text(":")

                Picker("Minute", selection: minuteBinding) {
                    ForEach(0...59, id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 55)
                .clipped()
            }
        }
        .labelsHidden()
        .frame(height: 170)
        .padding(.horizontal, 8)
        // Floating form needs its own backdrop — wheels on bare sky are
        // unreadable.
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    // MARK: - Component bindings

    private var dayBinding: Binding<Int> {
        Binding(get: { component(.day) },
                set: { setComponent(.day, $0) })
    }

    private var monthBinding: Binding<Int> {
        Binding(get: { component(.month) },
                set: { setComponent(.month, $0) })
    }

    private var yearBinding: Binding<Int> {
        Binding(get: { component(.year) },
                set: { setComponent(.year, $0) })
    }

    private var hourBinding: Binding<Int> {
        Binding(get: { component(.hour) },
                set: { setComponent(.hour, $0) })
    }

    private var minuteBinding: Binding<Int> {
        Binding(get: { component(.minute) },
                set: { setComponent(.minute, $0) })
    }

    // MARK: - Date math

    private func component(_ unit: Calendar.Component) -> Int {
        Calendar.current.component(unit, from: state.observationDate)
    }

    /// Rebuild the observation date with one component replaced.
    /// Clamps `day` to the range of the new month/year so changes in
    /// month/year can't construct an illegal date.
    private func setComponent(_ unit: Calendar.Component, _ value: Int) {
        let cal = Calendar.current
        var dc  = cal.dateComponents([.year, .month, .day,
                                      .hour, .minute, .second],
                                     from: state.observationDate)
        dc.setValue(value, for: unit)
        // Clamp day to the range of the new month/year.
        if unit == .month || unit == .year {
            if let probe = cal.date(from: DateComponents(year: dc.year,
                                                         month: dc.month)),
               let range = cal.range(of: .day, in: .month, for: probe),
               let day = dc.day {
                dc.day = min(day, range.upperBound - 1)
            }
        }
        guard let newDate = cal.date(from: dc) else { return }
        state.commitPickedObservationDate(newDate)
    }

    private var daysInCurrentMonth: Int {
        let cal = Calendar.current
        return cal.range(of: .day, in: .month, for: state.observationDate)?
            .count ?? 31
    }

    private var yearRange: ClosedRange<Int> {
        let current = Calendar.current.component(.year, from: .now)
        return (current - Self.yearSpan)...(current + Self.yearSpan)
    }

    private static func monthName(_ m: Int) -> String {
        let f = DateFormatter()
        // Short month names ("Jan", "Feb", ...) — wider than numerals,
        // narrower than full month names. Fits the wheel.
        return f.shortMonthSymbols[m - 1]
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.indigo, .black],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        VStack {
            Spacer()
            DatePickerPanel()
        }
    }
    .environment(AppState())
}
