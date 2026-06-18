import Foundation
import FoundationModels

// MARK: - MythStoryteller
// Warm, on-device "how it reached the sky" storyteller for a constellation.
// Grounds the Foundation Models on-device model in the app's own data —
// the catasterism line (ConstellationCatasterism), the cultural category
// (ConstellationCategories), and one live star fact — so the model RETELLS
// our canon rather than inventing one. Three tones (cosy / poetic / kid).
//
// Device-only: the on-device model needs Apple Intelligence on a real
// device. When it's unavailable (e.g. the Simulator) we fall back to the
// raw curated catasterism line, so the UI always shows something.
@MainActor
@Observable
final class MythStoryteller {

    /// Voice of the telling.
    enum Tone: String, CaseIterable, Identifiable {
        case cosy, poetic, kid
        var id: String { rawValue }

        var label: String {
            switch self {
            case .cosy:   "Cosy"
            case .poetic: "Poetic"
            case .kid:    "For kids"
            }
        }

        fileprivate var instruction: String {
            switch self {
            case .cosy:
                "Warm, gentle and conversational — like telling a friend under the stars."
            case .poetic:
                "Homeric, like a poem."
            case .kid:
                "Simple, playful and full of wonder, for a curious child. Short sentences, nothing frightening. Explain well the characters"
            }
        }
    }

    enum Phase: Equatable {
        case idle
        case generating
        case ready
        /// Model unavailable or generation failed — `text` holds the raw
        /// curated catasterism line instead. The String is a short reason.
        case fallback(String)
    }

    private(set) var text:  String = ""
    private(set) var phase: Phase  = .idle

    /// What we last told, so a re-appear doesn't needlessly regenerate.
    private(set) var lastKey: String?

    private var task: Task<Void, Never>?

    /// Generate the origin story for `cons` in `tone`. Cancels any in-flight
    /// telling. Falls back to the curated catasterism when the on-device
    /// model isn't available.
    func tell(_ cons: EConstellation, tone: Tone) {
        let key = "\(cons.rawValue)#\(tone.rawValue)"
        lastKey = key
        task?.cancel()

        let fallback = ConstellationCatasterism.shared.catasterism(for: cons) ?? ""

        guard case .available = SystemLanguageModel.default.availability else {
            text  = fallback
            phase = .fallback("on-device model unavailable")
            return
        }

        text  = ""
        phase = .generating
        let instructions = Self.persona(tone: tone)
        let prompt       = Self.prompt(for: cons)

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let session  = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: prompt)
                guard !Task.isCancelled else { return }
                self.text  = response.content
                self.phase = .ready
            } catch {
                guard !Task.isCancelled else { return }
                self.text  = fallback
                self.phase = .fallback(error.localizedDescription)
            }
        }
    }

    func cancel() { task?.cancel() }

    // MARK: - Grounding

    private static func persona(tone: Tone) -> String {
        """
        You are a warm, wonder-filled night-sky storyteller inside a stargazing app.
        Tell the origin of a constellation in about 5 or 6 sentences, ending on how it
        came to be set among the stars. \(tone.instruction)
        Stay strictly grounded in the facts you are given: never invent a myth, a
        character, or a fact that isn't provided. If no myth is given, do not pretend
        one exists — instead tell warmly how the constellation came to be charted and
        named. Write plain prose: no headings, no lists, no preamble.
        """
    }

    private static func prompt(for cons: EConstellation) -> String {
        let cat       = ConstellationCategories.shared.category(for: cons)
        let placement = ConstellationCatasterism.shared.catasterism(for: cons)

        var lines: [String] = ["Constellation: \(cons.fullName)."]
        if let entity = cat?.types.first { lines.append("It depicts a \(entity).") }
        if let saga = cat?.myths.first   { lines.append("It belongs to the \(saga) cycle of Greek myth.") }

        if let placement {
            lines.append("Canonical placement among the stars (retell in your own words, do not quote): \(placement)")
        } else {
            lines.append("There is no ancient myth for it — it is a modern constellation, charted by \(originPhrase(cat?.origin)). Tell warmly how it came to be named and set on the star map.")
        }

        if let facts = starFacts(for: cons) { lines.append(facts) }
        lines.append("Now tell its story.")
        return lines.joined(separator: "\n")
    }

    /// One light, real fact: the brightest member's name, colour, magnitude
    /// and (if known) distance — straight from the catalogue.
    private static func starFacts(for cons: EConstellation) -> String? {
        guard let b = cons.stars.min(by: { $0.magnitude < $1.magnitude }) else { return nil }
        var s = "You may weave in AT MOST TWO real facts, lightly: its most prominent star is "
            + "\(b.displayName), a \(colour(b.spectralClass)) star of magnitude "
            + String(format: "%.1f", b.magnitude)
        if let ly = b.distanceLY { s += ", about \(Int(ly.rounded())) light-years away" }
        s += "."
        return s
    }

    private static func colour(_ c: EHRClass) -> String {
        switch c.rawValue {
        case "O", "B": "blue-white"
        case "A":      "white"
        case "F":      "yellow-white"
        case "G":      "golden"
        case "K":      "orange"
        case "M":      "red"
        default:       "distant"
        }
    }

    private static func originPhrase(_ origin: String?) -> String {
        switch origin {
        case "lacaille": "Nicolas-Louis de Lacaille, mapping the southern sky in the 1750s"
        case "hevelius": "the astronomer Johannes Hevelius"
        case "bayer":    "Johann Bayer, charting the far-southern stars"
        default:         "later astronomers filling the gaps between the ancient figures"
        }
    }
}
