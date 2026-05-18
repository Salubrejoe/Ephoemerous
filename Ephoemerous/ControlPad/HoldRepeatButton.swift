import SwiftUI

// A button that fires once on press and then keeps firing while held —
// the behaviour a D-pad needs so latitude/longitude can be walked, not
// tapped one degree at a time.
struct HoldRepeatButton<Label: View>: View {

    let action:        () -> Void
    let repeatInterval: Double
    @ViewBuilder var label: () -> Label

    @State private var timer: Timer?

    init(repeatInterval: Double = 0.07,
         action: @escaping () -> Void,
         @ViewBuilder label: @escaping () -> Label) {
        self.action         = action
        self.repeatInterval = repeatInterval
        self.label          = label
    }

    var body: some View {
        label()
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: .infinity,
                                maximumDistance: .infinity,
                                perform: {},
                                onPressingChanged: { isPressing in
                                    isPressing ? startRepeating() : stopRepeating()
                                })
    }

    private func startRepeating() {
        action()                                   // immediate first step
        let t = Timer(timeInterval: repeatInterval, repeats: true) { _ in action() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopRepeating() {
        timer?.invalidate()
        timer = nil
    }
}
