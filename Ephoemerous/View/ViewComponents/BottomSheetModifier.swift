
import SwiftUI


extension View {
    func bottomSheet<Content: View>(
        _ title: Strings.Titles,
        isPresented: Binding<Bool>,
        content: @escaping () -> Content
    ) -> some View {
        modifier(
            BottomSheetModifier(
                title: title.rawValue,
                condition: isPresented,
                sheetView: content
            )
        )
    }
}


struct BottomSheetModifier<SheetView: View>: ViewModifier {
    
    let title     : String
    let condition : Binding<Bool>
    let sheetView : () -> SheetView
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: condition) {
                NavigationStack {
                    sheetView()
                        .navigationTitle(title)
                        .navigationBarTitleDisplayMode(.inline)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
    }
}


#Preview {
    MainView()
        .environment(EAppState())
}

