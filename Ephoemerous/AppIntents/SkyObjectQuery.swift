import AppIntents
import Foundation

// MARK: - SkyObjectQuery
// How the system enumerates and resolves `SkyObjectEntity`s.
//
//   • suggestedEntities — what a widget-configuration picker or the
//     Shortcuts parameter sheet OFFERS: Sun, Moon, the seven planets,
//     then every favourite (deduped — a favourited planet is already
//     in the fixed list). This is the user's exact ask: solar-system
//     bodies always, plus whatever they Remember.
//   • entities(for:)    — id → entity, for stored configurations.
//   • entities(matching:) — free-text (Siri / search field): matches
//     the suggestion pool PLUS every proper-named star, so "Sirius"
//     resolves even before it's ever been remembered.
struct SkyObjectQuery: EntityQuery, EntityStringQuery {

    @MainActor
    func entities(for identifiers: [String]) async throws -> [SkyObjectEntity] {
        identifiers.compactMap(SkyObjectEntity.init(id:))
    }

    @MainActor
    func suggestedEntities() async throws -> [SkyObjectEntity] {
        var out: [SkyObjectEntity] = []
        out.append(SkyObjectEntity(.sun))
        out.append(SkyObjectEntity(.moon))
        out.append(contentsOf: EPlanet.all.map { SkyObjectEntity(.planet($0)) })
        for fav in ECloudSync.shared.favourites() {
            let entity = SkyObjectEntity(fav)
            if !out.contains(where: { $0.id == entity.id }) { out.append(entity) }
        }
        return out
    }

    func defaultResult() async -> SkyObjectEntity? {
        SkyObjectEntity(.moon)
    }

    @MainActor
    func entities(matching string: String) async throws -> [SkyObjectEntity] {
        var pool = try await suggestedEntities()
        let seen = Set(pool.map(\.id))
        let named = StarDatabase.shared.workableStars
            .filter { $0.properName != nil }
            .map    { SkyObjectEntity(.star($0)) }
            .filter { !seen.contains($0.id) }
        pool.append(contentsOf: named)
        return pool.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
}
