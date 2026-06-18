import SwiftUI
import LoreKit

// MARK: - DatePickerPanel
// Inline panel that springs up above MainToolbar when the user taps
// the date pill. Five wheel `Picker`s — day / month / year / hour /
// minute — each bound to a single calendar component of
// `state.observationDate`. Writes route through
// `commitPickedObservationDate(_:)` so same-day edits animate the sky
// and day jumps cut cleanly (see EAppState+Time.swift for the
// routing rationale).
//
// Each wheel updates its component in isolation; when the user
// changes month or year we clamp `day` to the new month's max so we
// never construct an illegal date (e.g. 31 February).
struct DatePickerPanel: View {

    @Environment(EAppState.self) private var state

    /// 200-year span centred on the current year. Covers stargazing
    /// scenarios from historical (e.g. "sky over Paris during the
    /// Revolution") to forward projection ("Mars opposition in 2092").
    private static let yearSpan: Int = 100

    var body: some View {
        VStack(spacing: 8) {
            sheetHeader
            
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    Picker("Day", selection: dayBinding) {
                        ForEach(1...daysInCurrentMonth, id: \.self) { d in
                            Text("\(d)").tag(d)
//                                .font(.footnote)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 55)
                    .clipped()
                    
                    Picker("Month", selection: monthBinding) {
                        ForEach(1...12, id: \.self) { m in
                            Text(Self.monthName(m)).tag(m)
//                                .font(.footnote)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 76)
                    .clipped()
                    
                    Picker("Year", selection: yearBinding) {
                        ForEach(yearRange, id: \.self) { y in
                            Text(String(y)).tag(y)
//                                .font(.footnote)
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
//                                .font(.footnote)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 55)
                    .clipped()
                    
                    Text(":")
                    
                    Picker("Minute", selection: minuteBinding) {
                        ForEach(0...59, id: \.self) { m in
                            Text(String(format: "%02d", m)).tag(m)
//                                .font(.footnote)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 55)
                    .clipped()
                }
            }
            .labelsHidden()
            .frame(height: 160)
            
        Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 215)
    }

    // MARK: - Sheet header

    /// Title + a "Now" shortcut + the close X. Shared shape with
    /// `LocationPickerPanel.sheetHeader` so the two scene editors read
    /// as one family. "Now" commits via `commitPickedObservationDate(_:)`
    /// (same animate / jump rules as wheel edits); X just dismisses.
    private var sheetHeader: some View {
        HStack(spacing: 12) {
            Button {
                state.commitPickedObservationDate(.now)
            } label: {
                Text("Now")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 4)
                    .padding(.vertical,   2)
            }
            .buttonStyle(.glass)
            .disabled(abs(state.observationDate.timeIntervalSinceNow) < 60)
            .frame(width: 100, alignment: .leading)
            Spacer()
            
            Text("Date & Time")
                .font(.headline)
            // Greyed-and-blocked when the observation is already at
            // real-world now — same rule the other Now surfaces use.
                
            Spacer()
            
            Button { state.isShowingDatePicker = false } label: {
                Image(symbol: .xmark)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .glassEffect(.clear.interactive(), in: .circle)
            .frame(width: 100, alignment: .trailing)
        }
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
    /// Clamps `day` to the new month's max so changes in month/year
    /// can't construct an illegal date.
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
    DatePickerPanel()
        .environment(EAppState())
        .padding()
}
