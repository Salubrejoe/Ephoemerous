import SwiftUI

// Prototype — Game-Boy-style control surface for the bottom third.
// Left: a four-way D-pad nudging the observer (lat = up/down,
// lon = left/right). Right: date, location, default-view, search.
// Self-contained: drop GameBoyControlPad() over the canvas to try it.
struct GameBoyControlPad: View {

    @Environment(EAppState.self) private var state

    private let latitudeStep:  Double = 1.0   // degrees per D-pad step
    private let longitudeStep: Double = 1.0
    
    @State var isShowingArrowPad: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()

                VStack {
                    
                    
                    VStack {
                        
                        if isShowingArrowPad {
                            directionPad
                                .padding()
                                .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .blurReplace))
                        }
                        
                        if state.isShowingDatePicker {
                            datePickerPanel
                                .padding()
                                .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .blurReplace))
                        }
                        
                    }
                    
                    GlassEffectContainer {
                    HStack {
                        
                            
                            SearchBar()
                            Spacer()
                        
                        
                        
                            actionButton(
                                isShowingArrowPad ? "xmark" : "arcade.stick.and.arrow.up.and.arrow.down",
                                "Here",
                                color: .baseOrange
                            )    {
                                //                state.goToDeviceLocation()
                                isShowingArrowPad.toggle()
                            }
                        
                        
                        
                            actionButton(
                                state.isShowingDatePicker ? "xmark" : "\(Calendar.current.component(.day, from: .now)).calendar",
                                "Date",
                                color: .baseCoral
                            )    { state.toggleDatePicker() }
                        
                    }
                    
                    
                    
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .glassEffect(.clear.interactive(),
                             in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            }
            
        }
        .animation(.easeIn,
                   value: state.isShowingDatePicker)
        .animation(.easeIn,
                   value: isShowingArrowPad)

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
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
        }
    }

    func nudgeLatitude(by delta: Double) {
        
        state.coupledAxis = .vertical
        let lat = (state.origin.latitude.degrees + delta).clamped(to: -89 ... 89)
        state.setOrigin(lat: .degrees(lat), lon: state.origin.longitude)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            state.coupledAxis = .none
        }
    }

    func nudgeLongitude(by delta: Double) {
        state.coupledAxis = .horizontal
        var lon = (state.origin.longitude.degrees + delta)
            .truncatingRemainder(dividingBy: 360)
        if lon >  180 { lon -= 360 }
        if lon < -180 { lon += 360 }
        state.setOrigin(lat: state.origin.latitude, lon: .degrees(lon))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            state.coupledAxis = .none
        }
    }
}

// MARK: - Action cluster (date / location / default view / search)
private extension GameBoyControlPad {


    @ViewBuilder
    func actionButton(_ systemName: String, _ title: String,
                       longPress: (() -> Void)? = nil,
                      color: Color = .primary,
                       action: @escaping () -> Void) -> some View {
        let button = Button(action: action) {
            ZStack {
                Circle().fill(.ultraThinMaterial)
                Image(systemName: systemName)
                    .font(.title3)
                    .fontWeight(.light)
            }
            
            .foregroundStyle(.primary)
//            .foregroundStyle(color)
            .frame(width: 44, height: 44)
            .contentShape(Circle())                 // solid, predictable hit area
//            .background(.ultraThinMaterial, in: Circle())
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
        LinearGradient(colors: [.blue, .pink],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        GameBoyControlPad()
            .environment(EAppState())
    }
}
