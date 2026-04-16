import SwiftUI
import os

struct EDatePicker: View {
    
    @Environment(EAppState.self) var state
    
    var body: some View {
        VStack {
            Spacer()
            let bindableState = Bindable(state)
            if state.isEditingDate {
                EDateSliders(state: bindableState)
                    .monospaced()
                    .padding(.vertical, 16)
                    .padding(.horizontal, 32)
                    .glassEffect(.regular.interactive(), in: .containerRelative)
//                    .background(
//                        RoundedRectangle(cornerRadius: 20, style: .continuous)
//                            .fill(.ultraThinMaterial)
//                    )
            }
        }
        .padding()
        .tint(.pink)
        .animation(.easeInOut, value: state.isEditingDate)
    }
}


struct EDateSliders: View {
    
    @Bindable var state   : EAppState
    @State private var vm : EDatePickerViewModel
    
    init(state: Bindable<EAppState>) {
        self._state = .init(projectedValue: state)
        self._vm = State(initialValue: .init(with: state.wrappedValue))
    }
    
    var body: some View {
        VStack(spacing: 8) {
            LabeledContent("Y: \(vm.year % 2000)") {
                Slider(value: Binding(
                    get: { Double(vm.year) },
                    set: { vm.year = Int($0.rounded())
                        state.observationDate = vm.newObservationDate()
                    }
                ), in: 1900...2100, step: 1)
            }
            LabeledContent("M: \(vm.month)") {
                Slider(value: Binding(
                    get: { Double(vm.month) },
                    set: {
                        vm.month = Int($0.rounded())
                        if !vm.validDayRange.contains(vm.day) { vm.day = vm.validDayRange.upperBound }
                        state.observationDate = vm.newObservationDate()
                    }
                ), in: 1...12, step: 1)
            }
            LabeledContent("D: \(vm.day)") {
                Slider(value: Binding(
                    get: { Double(vm.day) },
                    set: {
                        vm.day = Int($0.rounded())
                        vm.day = min(max(vm.day, vm.validDayRange.lowerBound), vm.validDayRange.upperBound)
                        state.observationDate = vm.newObservationDate()
                    }
                ), in: Double(vm.validDayRange.lowerBound)...Double(vm.validDayRange.upperBound), step: 1)
            }
            LabeledContent("H: \(vm.hour)") {
                Slider(value: Binding(
                    get: { Double(vm.hour) },
                    set: { vm.hour = Int($0.rounded())
                        state.observationDate = vm.newObservationDate()
                    }
                ), in: 0...23, step: 1)
            }
            
        }
    }
}


@Observable
final class EDatePickerViewModel {
    var day   : Int
    var month : Int
    var year  : Int
    var hour  : Int
    
    init(with appState: EAppState) {
        let cal = Calendar.current
        let date = appState.observationDate
        day   = cal.component(.day,   from: date)
        month = cal.component(.month, from: date)
        year  = cal.component(.year,  from: date)
        hour  = cal.component(.hour,  from: date)
    }
    
    var validDayRange: ClosedRange<Int> {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        let cal = Calendar.current
        if let date = cal.date(from: comps),
           let range = cal.range(of: .day, in: .month, for: date) {
            return range.lowerBound ... range.upperBound
        }
        return 1...31
    }
    
    func newObservationDate() -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = min(max(day, validDayRange.lowerBound), validDayRange.upperBound)
        comps.hour = hour
        comps.minute = 0
        comps.second = 0
        let cal = Calendar.current
        if let newDate = cal.date(from: comps) {
            return newDate
        } else {
            Logger().log("[EDatePickerViewModel](.newObservationDate): Failed to create date from: \(comps)")
            return Date()
        }
    }
}


