
import SwiftUI

struct DateButton: View {
    @Environment(EAppState.self) var state
    
    var body: some View {
        
        HStack {
            if state.isShowingDatePicker {
                
                ObservationDatePicker()
                DismissPickerXmark()
                
            } else {
                CalendarButton()
            }
            
            if dateValueChanged {
                ResetDateButton()
            }
        }
    }
}


// MARK: - Components
extension DateButton {
    
    @ViewBuilder
    private func ObservationDatePicker() -> some View {
        let bindableState = Bindable(state)
        DatePicker("",
                   selection: bindableState.observationDate,
                   displayedComponents: [.date, .hourAndMinute]
        )
    }
    
    @ViewBuilder
    private func CalendarButton() -> some View {
        Button {
            state.isShowingDatePicker.toggle()
        } label: {
            Image(symbol: .calendar)
        }
    }
    
    @ViewBuilder
    private func ResetDateButton() -> some View {
        Button {
            state.observationDate = .now
        } label: {
            Image(symbol: .resetClock)
        }
    }
    
    @ViewBuilder
    private func DismissPickerXmark() -> some View {
        Button {
            state.isShowingDatePicker.toggle()
        } label: {
            Image(symbol: .xmark)
        }
    }
}


// MARK: - Helpers
extension DateButton {
    
    private var dateValueChanged: Bool {
        hourValueChanged || minuteValueChanged || isNotToday
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
