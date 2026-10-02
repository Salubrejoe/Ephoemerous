import SwiftUI

// MARK: - SkyStatusLine
// The detail header's single subtitle: "● Up · 41° W · sets 14:20". The dot
// wears the accent while the object is up — the accent means "live" — and
// goes hollow and grey once it's below the horizon. See `SkyStatus`.
struct SkyStatusLine: View {

    @Environment(AppState.self) private var state

    let object: SkyObject

    var body: some View {
        if let status = SkyStatus.cached(object: object,
                                         date:     state.observationDate,
                                         observer: SatelliteSky.Observer(latitude:  state.origin.latitude.radians,
                                                                         longitude: state.origin.longitude.radians)) {
            HStack(spacing: 6) {
                dot(isUp: status.isUp)
                Text(status.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(status.isUp ? .primary : .secondary)
                if let detail = status.detail {
                    Text(verbatim: "· \(detail)")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .monospacedDigit()
        }
    }

    @ViewBuilder
    private func dot(isUp: Bool) -> some View {
        if isUp {
            Circle().fill(Color.accentColor).frame(width: 8, height: 8)
        } else {
            Circle().strokeBorder(.secondary, lineWidth: 1.5).frame(width: 8, height: 8)
        }
    }
}
