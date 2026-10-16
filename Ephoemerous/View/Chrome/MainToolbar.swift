import SwiftUI
import LoreKit


struct MainToolbar: View {

    @Environment(AppState.self) private var state
    @Environment(\.scenePhase)   private var scenePhase

    /// Bumped on appear and on every scene-becomes-active so the
    /// label computed properties recompute. The Here / Now strings
    /// depend on `Date.now` and the device-location fix — neither is
    /// `@Observable`, so without a tick like this the label can sit
    /// at "Now" forever after the phone has been left on the table
    /// (the body never has any reason to re-evaluate).
    @State private var refreshTick: Int = 0

    /// Morph namespace so the flanking reset chips grow out of / melt back
    /// into the status capsule (Liquid Glass `glassEffectID`).
    @Namespace private var glassNS

    /// Capsule + reset-chip height. The iPad passes a taller one — the
    /// phone's chrome on a 13" canvas reads as a toy. ▼ TWEAK ▼
    var barHeight: CGFloat = 40

    
    
    // MARK: - body
    var body: some View {
        // Reading `refreshTick` here registers the dependency for
        // every label call downstream; bumping the tick re-renders
        // the toolbar and rewalks the timeLabel / placeLabel
        // computed properties.
        let _ = refreshTick
        // Status capsule flanked by two reset chips. The pills show the
        // current value (Here/London, Now/21:40) and raise a bottom-sheet
        // editor; the chips appear OUTSIDE the capsule when the observer
        // has drifted off Here / Now — a one-tap "go back". They morph out
        // of (and melt back into) the capsule via the Liquid Glass
        // container + `glassEffectID`, so they read as growing from its
        // ends. Leading chip ↔ location (Here); trailing chip ↔ date (Now).
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                if state.isAwayFromHere {
                    ToolbarResetButton(
                        size:   barHeight,
                        symbol: "location.fill",             // back to HERE
                        action: state.goToDeviceLocation
                    )
                    .glassEffectID("resetHere", in: glassNS)
                    .transition(.offset(x: barHeight).combined(with: .opacity))
                }

                HStack(spacing: 0) {
                    // Turning the crown collapses the readout to the DATE
                    // ALONE — the location isn't changing, and the shorter
                    // capsule leaves room for the whole thing to swell (below)
                    // without spilling past the screen edges. Location slides
                    // back in when the wheel stops. ▼ TWEAK the emphasis here ▼
                    if !state.isScrubbingDate {
                        ToolbarPill(
                            state.placeLabel,
                            action: state.toggleLocationPicker
                        )
                        .transition(.opacity)
                        Divider()
                            .padding(.vertical, 8)
                            .transition(.opacity)
                    }
                    ToolbarPill(
                        state.timeLabel,
                        action: state.toggleDatePicker
                    )
                }
                .frame(height: barHeight)
                .glassEffect(.regular.interactive(), in: .capsule)
                .glassEffectID("bar", in: glassNS)

                if state.isAwayFromNow {

                    ToolbarResetButton(
                        size:   barHeight,
                        symbol: "clock.arrow.circlepath",    // back to NOW
                        action: state.returnToNow
                    )
                    .glassEffectID("resetNow", in: glassNS)
                    .transition(.offset(x: -barHeight).combined(with: .opacity))
                }
            }
        } //: GlassEffectContainer
        // Whole readout swells as one unit — the capsule mask grows with its
        // content, so the enlarged date can't clip at any length.
        .scaleEffect(state.isScrubbingDate ? 1.16 : 1)
        .animation(.spring(response: 0.32, dampingFraction: 0.6),
                   value: state.isScrubbingDate)
        
       
        // MARK: - REFRESH HERE/NOW
        
        // Animate the chips growing in / shrinking out as the flags flip.
        .animation(.bouncy, value: state.isAwayFromHere)
        .animation(.bouncy, value: state.isAwayFromNow)
        
        // Bump the refresh tick on initial appear and every time the
        // scene returns to `.active` (phone woken from sleep, app
        // returning from background). Re-evaluating the body recomputes
        // the timeLabel / placeLabel — and `isAwayFromNow` — against the
        // current wall-clock and device-location fix.
        .onAppear { refreshTick &+= 1 }
        .onChange(of: scenePhase) { _, new in
            if new == .active { refreshTick &+= 1 }
        }
    }
}

#if DEBUG
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
    .environment(AppState())
}
#endif
