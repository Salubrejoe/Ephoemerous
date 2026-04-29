
import SwiftUI

struct DateButton: View {
    @Environment(EAppState.self) var state
    
    var body: some View {
        
        HStack(spacing: 4) {
            if dateValueChanged {
                ResetDateButton()
                    .padding(.leading, 4)
            }
            
            if state.isShowingDatePicker {
                ObservationDatePicker()
                    .padding(.horizontal, dateValueChanged ? 4 : 0)
                DismissPickerXmark()
                    .padding(.trailing, 4)
            }
            else {
                CalendarButton()
                    .padding(.horizontal, dateValueChanged ? 4 : 0)
            }
        }
        .animation(.bouncy, value: state.isShowingDatePicker)
        .animation(.bouncy, value: dateValueChanged)
    }
}


// MARK: - Components
extension DateButton {
    
    @ViewBuilder
    private func ObservationDatePicker() -> some View {
        let binding = Binding<Date>(
            get: { state.observationDate },
            set: { newDate in
                let old = state.observationDate
                let cal = Calendar.current
                let onlyTimeChanged = cal.isDate(old, inSameDayAs: newDate)
                if onlyTimeChanged {
                    state.setObservationDate(newDate)
                } else {
                    state._dateTransition = nil
                    state.observationDate  = newDate
                }
                state.applyTimeOfDayPreset()
            }
        )
        DatePicker("",
                   selection: binding,
                   displayedComponents: [.date, .hourAndMinute]
        )
        .pickerStyle(.wheel)
        .labelsHidden()
        
    }
    
    @ViewBuilder
    private func CalendarButton() -> some View {
        Button {
            if !state.isShowingDatePicker {
                state.apply(EViewPreset(
                    id: "_default",
                    name: Strings.Preset.defaultPreset,
                    symbol: "circle",
                    scale: AstroConstants.defaultScale,
                    offset: CGPoint(x: AstroConstants.defaultOffsetX, y: AstroConstants.defaultOffsetY)
                ))
            }
            state.isShowingDatePicker.toggle()
        } label: {
            Image(symbol: .calendar)
        }
    }
    
    @ViewBuilder
    private func ResetDateButton() -> some View {
        Button {
            state.setObservationDate(.now)
        } label: {
            Image(symbol: .resetClock)
                .foregroundStyle(.pink)
        }
    }
    
    @ViewBuilder
    private func DismissPickerXmark() -> some View {
        Button {
            state.isShowingDatePicker.toggle()
        } label: {
            Image(symbol: .xmarkCircle)
                .foregroundStyle(.secondary)
        }
    }
}


// MARK: - Helpers
extension DateButton {
    
    private var dateValueChanged: Bool {
        hourValueChanged
        || minuteValueChanged
//        || isNotToday
    }
    
    private var isNotToday: Bool {
        Calendar.current.isDateInToday(state.observationDate)
    }
    
    private var hourValueChanged: Bool {
        currentHour != observationHour
    }
    
    private var minuteValueChanged: Bool {
        currentHour != observationHour
    }
    
    private var currentHour: Int {
        Calendar.current.component(.hour, from: .now)
    }
    
    private var observationHour: Int {
        Calendar.current.component(.hour, from: state.observationDate)
    }
    
    private var currentMinute: Int {
        Calendar.current.component(.minute, from: .now)
    }
    
    private var observationHMinute: Int {
        Calendar.current.component(.minute, from: state.observationDate)
    }
}


#Preview {
    DateButton()
        .environment(EAppState())
}
