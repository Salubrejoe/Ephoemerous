import SwiftUI

// MARK: - DatePickerPanel
// Inline panel that springs up above MainToolbar when the user taps
// the date pill. A compact native DatePicker bound to a custom binding
// that routes writes through `commitPickedObservationDate(_:)` so
// same-day edits animate the sky and day jumps cut cleanly (see
// EAppState+Time.swift for the routing rationale).
struct DatePickerPanel: View {

    @Environment(EAppState.self) private var state

    var body: some View {
        DatePicker("",
                   selection: observationDateBinding,
                   displayedComponents: [.date, .hourAndMinute])
            .labelsHidden()
            .datePickerStyle(.compact)
            .padding(.horizontal, 14)
            .padding(.vertical,    8)
            .glassEffect(.clear, in: .capsule)
    }

    private var observationDateBinding: Binding<Date> {
        Binding(get: { state.observationDate },
                set: { state.commitPickedObservationDate($0) })
    }
}

#Preview {
    DatePickerPanel()
        .environment(EAppState())
        .padding()
}
