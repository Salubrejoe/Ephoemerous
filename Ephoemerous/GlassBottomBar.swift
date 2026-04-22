import SwiftUI

// MARK: - Detents

enum SheetDetent: CGFloat, CaseIterable {
    case collapsed = 88
    case peek = 340
    case full = 0 // computed at runtime

    func height(in total: CGFloat) -> CGFloat {
        self == .full ? total * 0.92 : self.rawValue
    }
}

// MARK: - GlassBottomBar

struct GlassBottomBar<Content: View>: View {
    let content: () -> Content

    @State private var detent: SheetDetent = .collapsed
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false

    private let horizontalPadding: CGFloat = 12
    private let bottomPadding: CGFloat = 8
    private let cornerRadius: CGFloat = 44

    var body: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height
            let targetHeight = detent.height(in: totalHeight)
            let currentHeight = max(
                SheetDetent.collapsed.height(in: totalHeight),
                min(SheetDetent.full.height(in: totalHeight), targetHeight - dragOffset)
            )
            let isExpanded = detent != .collapsed

            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(.secondary.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                // Content
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .opacity(isExpanded ? 1 : 0)
                    .animation(.easeInOut(duration: 0.18), value: isExpanded)
            }
            .frame(maxWidth: .infinity)
            .frame(height: currentHeight)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
//                    .overlay {
//                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
//                            .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
//                    }
//                    .overlay(alignment: .top) {
//                        // specular highlight
//                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
//                            .fill(
//                                LinearGradient(
//                                    colors: [.white.opacity(0.10), .clear],
//                                    startPoint: .top,
//                                    endPoint: .center
//                                )
//                            )
//                    }
            }
            .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: -4)
            .padding(.horizontal, horizontalPadding)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, bottomPadding)
            .gesture(
                DragGesture(minimumDistance: 8)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.height - value.translation.height
                        snapDetent(dragDelta: value.translation.height, velocity: velocity, totalHeight: totalHeight)
                        dragOffset = 0
                    }
            )
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: detent)
            .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: dragOffset)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func snapDetent(dragDelta: CGFloat, velocity: CGFloat, totalHeight: CGFloat) {
        let allDetents = SheetDetent.allCases
        let currentH = detent.height(in: totalHeight) - dragDelta
        let combined = dragDelta + velocity * 0.18

        let best = allDetents.min(by: {
            abs($0.height(in: totalHeight) - currentH + (combined > 0 ? 60 : -60))
            < abs($1.height(in: totalHeight) - currentH + (combined > 0 ? 60 : -60))
        })
        detent = best ?? .collapsed
    }
}


struct TestView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.14, blue: 0.18), Color(red: 0.05, green: 0.10, blue: 0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            GlassBottomBar {
                VStack(alignment: .leading, spacing: 0) {
                    // Search row -- always visible first
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        Text("Search")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    
                    Divider().padding(.horizontal, 16)
                    
                    // Expanded content
                    ForEach(["Home", "Work", "Coffee Shop"], id: \.self) { place in
                        HStack(spacing: 12) {
                            Image(systemName: "clock")
                                .frame(width: 32, height: 32)
                                .background(.secondary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Text(place)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TestView()
}
