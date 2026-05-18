
import SwiftUI

let eButtonHeight: CGFloat = 55
let corner: CGFloat = 48


struct MockupMainView: View {
    @State private var date : Date = .now
    @State private var isShowingDateResetButton : Bool = false
    @State private var isShowingSettings        : Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color
                    .quaternarySystemFill
                    .ignoresSafeArea()
                
                header()
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                
                GlassEffectContainer() {
                    ZStack {
                        animeButton()
                    }
                    .padding(eButtonHeight/2)
                    .border(.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
                
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
    
    @ViewBuilder
    private func header() -> some View {
        HStack(alignment: .center, spacing: 4) {
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Image(systemName: "location.fill")
                    .imageScale(.small)
                Text("Peacehaven")
            }//: Location Group
            .font(.headline)
            .foregroundStyle(.tertiary)
            
            Spacer()
            Group {
                DatePicker("", selection: $date, displayedComponents: [.date])
                    .labelsHidden()
                    .onChange(of: date) { _, newValue in
                        withAnimation(.easeIn(duration: 0.22)) {
                            if newValue != .now {
                                isShowingDateResetButton = true
                            } else {
                                isShowingDateResetButton = false
                            }
                        }
                    }
                if isShowingDateResetButton {
                    Button {
                        //
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.orange)
                    }
                }
                
            }//: Date Group
        }//: Header HStack
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        
    }
    
    @ViewBuilder
    private func animeButton() -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            
            if isShowingSettings {
                EButton {} label: {
                    Image(symbol: .magnitudeIcon)
                }
                
                EButton {} label: {
                    Image(systemName: "map")
                }
                
                EButton {} label: {
                    Image(systemName: "square.3.layers.3d")
                }
            }
            
            EButton(tint: isShowingSettings ? .orange : .primary) {
                withAnimation(.bouncy(duration: 0.65)) {
                    isShowingSettings.toggle()
                }
            } label: {
                Image(systemName: isShowingSettings ? "xmark" : "gearshape.fill")
            }
        }//: Anime Settings VStack
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

#Preview {
    MockupMainView()
}


struct EButton<Label: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let action: () -> Void
    let label: () -> Label
    let tint: Color?
    
    init(
        tint  : Color? = nil,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.label = label
        self.tint = tint
    }
    
    var body: some View {
        Button {
            action()
        } label : {
            Circle()
                .fill(.clear)
                .frame(width: eButtonHeight, height: eButtonHeight)
                .overlay {
                    label()
                        .fontWeight(.semibold)
                        .foregroundStyle(glassColor)
                        .imageScale(.large)
                }
        }
        .glassEffect(.clear.interactive(), in: .circle)
    }
    
    private var primaryColor: Color {
        colorScheme == .dark ? .black : .white
    }
    
    private var glassColor: Color {
        tint ?? .primary
    }
}


