
import SwiftUI

struct DateButton: View {
    @Environment(EAppState.self) var state

    var body: some View {
        HStack(spacing: 4) {
            if state.observationDiffersFromNow {
                ResetDateButton()
                    .padding(.leading, 4)
            }

            if state.isShowingDatePicker {
                ObservationDatePicker()
                    .padding(.horizontal, state.observationDiffersFromNow ? 4 : 0)
                DismissPickerXmark()
                    .padding(.trailing, 4)
            } else {
                CalendarButton()
                    .padding(.horizontal, state.observationDiffersFromNow ? 4 : 0)
            }
        }
        .animation(.bouncy, value: state.isShowingDatePicker)
        .animation(.bouncy, value: state.observationDiffersFromNow)
    }
}


// MARK: - Components
extension DateButton {

    @ViewBuilder
    private func ObservationDatePicker() -> some View {
        let binding = Binding<Date>(
            get: { state.observationDate },
            set: { state.commitPickedObservationDate($0) }
        )
        DatePicker("",
                   selection: binding,
                   displayedComponents: [.date, .hourAndMinute])
            .labelsHidden()
    }

    @ViewBuilder
    private func CalendarButton() -> some View {
        Button(action: state.toggleDatePicker) {
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


#Preview {
    DateButton()
        .environment(EAppState())
}
