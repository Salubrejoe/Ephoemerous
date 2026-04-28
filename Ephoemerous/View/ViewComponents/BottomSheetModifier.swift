
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
    @Environment(\.dismiss) var dismiss
    
    let title     : String
    let condition : Binding<Bool>
    let sheetView : () -> SheetView
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: condition) {
                NavigationStack {
                    sheetView()
                        .presentationBackground(.clear)
                        .presentationBackgroundInteraction(.enabled)
//                        .navigationTitle(title)
//                        .navigationBarTitleDisplayMode(.large)
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

