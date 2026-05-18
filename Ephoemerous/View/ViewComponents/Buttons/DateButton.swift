
import SwiftUI

struct DateButton: View {
    @Environment(EAppState.self) var state
    
    @State private var dateChanged : Bool = false
    
    var body: some View {
        
        HStack(spacing: 4) {
            if dateChanged {
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
        .onAppear(perform: checkDate)
        .onChange(of: state.observationDate) { checkDate() }
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
                let projMode = state.projectionMode
                if onlyTimeChanged {
                    state.setObservationDate(newDate)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        state.projectionMode = projMode
                    }
                } else {
                    state._dateTransition = nil
                    state.observationDate  = newDate
                }
                state.projectionMode = .coupled
                
            }
        )
        DatePicker("",
                   selection: binding,
                   displayedComponents: [.date, .hourAndMinute]
        )
//        .pickerStyle(.menu)
        .labelsHidden()
        
    }
    
    @ViewBuilder
    private func CalendarButton() -> some View {
        Button {
            if !state.isShowingDatePicker {
                state.resetView()
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
                .foregroundStyle(.blue)
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
    
    private func checkDate() {
        dateChanged = dateValueChanged
    }
    
    private var dateValueChanged: Bool {
        hourValueChanged
        || minuteValueChanged
        || isNotToday
    }
    
    private var isNotToday: Bool {
        !Calendar.current.isDateInToday(state.observationDate)
    }
    
    private var hourValueChanged: Bool {
        currentHour != observationHour
    }
    
    private var minuteValueChanged: Bool {
        currentMinute != observationMinute
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
    
    private var observationMinute: Int {
        Calendar.current.component(.minute, from: state.observationDate)
    }
}


#Preview {
    DateButton()
        .environment(EAppState())
}
