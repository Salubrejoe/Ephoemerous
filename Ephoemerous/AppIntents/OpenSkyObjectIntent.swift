import AppIntents
import Foundation

// MARK: - OpenSkyObjectIntent
// "Show me Mars" — opens the app focused on a sky object: the same
// `focus(on:)` path a canvas tap or search pick takes (detail card up,
// comfort-pan to the object), so an intent launch lands EXACTLY like an
// in-app selection. Doubles as the tap-through intent for widgets: a
// widget cell deep-links by embedding this with its configured entity.
struct OpenSkyObjectIntent: AppIntent {

    static let title: LocalizedStringResource = "Show Sky Object"
    static let description = IntentDescription(
        "Opens Ephoemerous focused on a star, planet, constellation, the Sun or the Moon."
    )
    static let openAppWhenRun = true

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$target)")
    }

    @Parameter(title: "Object")
    var target: SkyObjectEntity

    /// The live app state, registered in `EphoemerousApp.init` via
    /// `AppDependencyManager` — intents run in the app process, so this
    /// is the same instance the views observe.
    @Dependency
    private var appState: AppState

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let obj = target.skyObject else {
            throw SkyObjectError.unresolved(target.name)
        }
        appState.focus(on: obj)
        return .result()
    }
}

// MARK: - SkyObjectError
/// A stored entity id that no longer resolves (a star renamed out of the
/// database between OS launches) — surfaced as a readable Siri failure.
enum SkyObjectError: Error, CustomLocalizedStringResourceConvertible {
    case unresolved(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .unresolved(let name): "Couldn't find \(name) in the sky database."
        }
    }
}

// MARK: - EphoemerousShortcuts
// System-surfaced phrases (Spotlight, Siri, the Shortcuts gallery).
// Parameterised on the entity, so the object names offered come from
// `suggestedEntities` — Sun / Moon / planets / favourites by name.
struct EphoemerousShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent:  OpenSkyObjectIntent(),
            phrases: [
                "Show \(\.$target) in \(.applicationName)",
                "Where is \(\.$target) in \(.applicationName)",
                "Find \(\.$target) in \(.applicationName)",
            ],
            shortTitle:      "Show Sky Object",
            systemImageName: "sparkles"
        )
    }
}
