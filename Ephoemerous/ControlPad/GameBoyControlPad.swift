import SwiftUI

// Prototype — Game-Boy-style control surface for the bottom third.
// Left: a four-way D-pad nudging the observer (lat = up/down,
// lon = left/right). Right: date, location, default-view, search.
// Self-contained: drop GameBoyControlPad() over the canvas to try it.
struct GameBoyControlPad: View {

    @Environment(EAppState.self) private var state

    private let latitudeStep:  Double = 1.5   // degrees per D-pad step
    private let longitudeStep: Double = 1.5

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            if state.isShowingDatePicker {
                datePickerPanel
                    .transition(.move(edge: .trailing).combined(with: .opacity).combined(with: .blurReplace))
            }

            GlassEffectContainer {
                HStack(alignment: .center, spacing: 0) {
                    directionPad
                    Spacer(minLength: 12)
                    actionCluster
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 16)
                .glassEffect(.clear.interactive(),
                             in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .animation(.easeIn,
                   value: state.isShowingDatePicker)
    }
}

// MARK: - Date picker panel (springs up from the console)
private extension GameBoyControlPad {

    var observationDateBinding: Binding<Date> {
        Binding(get: { state.observationDate },
                set: { state.commitPickedObservationDate($0) })
    }

    var datePickerPanel: some View {
        DatePicker("",
                   selection: observationDateBinding,
                   displayedComponents: [.date, .hourAndMinute])
            .labelsHidden()
            .datePickerStyle(.compact)
//            .frame(maxWidth: .infinity)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .glassEffect(.clear,
                         in: .capsule)
    }
}

// MARK: - Direction pad (observer latitude / longitude)
private extension GameBoyControlPad {

    var directionPad: some View {
        let arm: CGFloat = 44
        return ZStack {
            arrow("chevron.up")    { nudgeLatitude(by:  latitudeStep)  }
                .offset(y: -arm)
            arrow("chevron.down")  { nudgeLatitude(by: -latitudeStep)  }
                .offset(y:  arm)
            arrow("chevron.left")  { nudgeLongitude(by: -longitudeStep) }
                .offset(x: -arm)
            arrow("chevron.right") { nudgeLongitude(by:  longitudeStep) }
                .offset(x:  arm)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 26, height: 26)
        }
        .frame(width: arm * 2 + 54, height: arm * 2 + 54)
    }

    func arrow(_ systemName: String,
               action: @escaping () -> Void) -> some View {
        HoldRepeatButton(action: action) {
            Image(systemName: systemName)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    func nudgeLatitude(by delta: Double) {
        let lat = (state.origin.latitude.degrees + delta).clamped(to: -89 ... 89)
        state.setOrigin(lat: .degrees(lat), lon: state.origin.longitude)
    }

    func nudgeLongitude(by delta: Double) {
        var lon = (state.origin.longitude.degrees + delta)
            .truncatingRemainder(dividingBy: 360)
        if lon >  180 { lon -= 360 }
        if lon < -180 { lon += 360 }
        state.setOrigin(lat: state.origin.latitude, lon: .degrees(lon))
    }
}

// MARK: - Action cluster (date / location / default view / search)
private extension GameBoyControlPad {

    var actionCluster: some View {
        Grid(horizontalSpacing: 14, verticalSpacing: 14) {
            GridRow {
                actionButton("calendar",       "Date")    { state.toggleDatePicker() }
                actionButton("location.fill",  "Here")    { state.goToDeviceLocation() }
            }
            GridRow {
                // Like the old CircledResetButton: tap → default scale &
                // offset; long-press → toggle app mode.
                actionButton("viewfinder", "Default",
                             longPress: { state.toggleAppMode() }) {
                    state.resetView()
                }
                actionButton("magnifyingglass", "Search") { state.showStarList.toggle() }
            }
        }
    }

    @ViewBuilder
    func actionButton(_ systemName: String, _ title: String,
                       longPress: (() -> Void)? = nil,
                       action: @escaping () -> Void) -> some View {
        let button = Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemName)
                    .font(.title3.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .frame(width: 56, height: 52)
            .contentShape(Circle())                 // solid, predictable hit area
            .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)

        if let longPress {
            button.simultaneousGesture(
                LongPressGesture().onEnded { _ in longPress() }
            )
        } else {
            button
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.darkIndigo, .darkBerry],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        GameBoyControlPad()
            .environment(EAppState())
    }
}
