import SwiftUI

// MARK: - Sort & Filter models

enum EStarSort: String, CaseIterable, Identifiable {
    case magnitude     = "Magnitude"
    case constellation = "Constellation"
    case name          = "Name"
    var id: String { rawValue }
}

struct EStarListView: View {

    @Environment(EAppState.self) var state
    @Environment(\.dismiss) var dismiss

    @State private var searchText    = ""
    @State private var sortOrder     = EStarSort.magnitude
    @State private var magnitudeCap  = 6.5
    @State private var showSortSheet = false

    private let magnitudeRange = -2.0...8.0

    private var baseStars: [EStar] {
        StarDatabase.shared.workableStars.filter { $0.name != "Unknown" }
    }

    private var displayed: [EStar] {
        var result = baseStars.filter { $0.magnitude <= magnitudeCap }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.displayName.lowercased().contains(q) ||
                $0.constellation.fullName.lowercased().contains(q) ||
                $0.spectralClass.rawValue.lowercased().contains(q)
            }
        }
        switch sortOrder {
        case .magnitude:     result.sort { $0.magnitude < $1.magnitude }
        case .constellation: result.sort { $0.constellation.fullName < $1.constellation.fullName }
        case .name:          result.sort { $0.name < $1.name }
        }
        return result
    }

    // Recent stars that also pass the active magnitude filter (keep list consistent)
    private var recentDisplayed: [EStar] {
        state.recentStars.filter { $0.magnitude <= magnitudeCap }
    }

    var body: some View {
        List {
            // ── Recently Viewed ──────────────────────────────────────────
            if searchText.isEmpty && !recentDisplayed.isEmpty {
                Section {
                    ForEach(recentDisplayed) { star in
                        NavigationLink(value: star) {
                            EStarRowView(star: star)
                        }
                    }
                } header: {
                    Text("Recently Viewed")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }

            // ── Full List ────────────────────────────────────────────────
            Section {
                ForEach(displayed) { star in
                    NavigationLink(value: star) {
                        EStarRowView(star: star)
                    }
                }
            } header: {
                if searchText.isEmpty && !recentDisplayed.isEmpty {
                    Text("All Stars")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
        .navigationTitle("Stars")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Name, constellation, class...")
        .scrollContentBackground(.hidden)
        .preferredColorScheme(.dark)
        .navigationDestination(for: EStar.self) { star in
            EStarDetailView(star: star)
                .onAppear { state.recordViewed(star) }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSortSheet = true } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
            
            ToolbarItem(placement: .destructiveAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
        .sheet(isPresented: $showSortSheet) {
            ESortFilterSheet(
                sortOrder: $sortOrder,
                magnitudeCap: $magnitudeCap,
                magnitudeRange: magnitudeRange,
                starCount: displayed.count
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
//            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Sort & Filter Sheet

private struct ESortFilterSheet: View {
    @Binding var sortOrder: EStarSort
    @Binding var magnitudeCap: Double
    let magnitudeRange: ClosedRange<Double>
    let starCount: Int

    var body: some View {
        NavigationStack {
            List {
                Section("Sort by") {
                    ForEach(EStarSort.allCases) { option in
                        HStack {
                            Text(option.rawValue)
                            Spacer()
                            if sortOrder == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { sortOrder = option }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Brighter than")
                            Spacer()
                            Text(String(format: "%.1f mag", magnitudeCap))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $magnitudeCap, in: magnitudeRange, step: 0.5)
                            .tint(.blue)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.white.opacity(0.05))
                } header: {
                    Text("Magnitude filter")
                } footer: {
                    Text("\(starCount) stars shown")
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Sort & Filter")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Row

private struct EStarRowView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(EAppState.self) var state
    let star: EStar

    var body: some View {
        HStack(spacing: 12) {
            let r = max(4.0, min(14.0, (6.5 - star.magnitude) * 2.2))
//            Circle()
//                .fill(star.spectralClass.color)
           
            Button {
                state.selectedStar = star
            } label: {
                Image(systemName: state.selectedStar == star ? "target" : "circle.fill")
                    .foregroundStyle(star.spectralClass.color)
                    .padding(9)
            }
            .glassEffect(.clear.tint(star.spectralClass.color.opacity(0.2)).interactive(), in: .circle)
            

            VStack(alignment: .leading, spacing: 2) {
                Text(star.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(star.constellation.fullName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2f", star.magnitude))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(star.spectralClass.rawValue)
                    .font(.caption2)
                    .foregroundStyle(star.spectralClass.color)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        EStarListView()
    }
    .environment(EAppState())
    .preferredColorScheme(.dark)
}
