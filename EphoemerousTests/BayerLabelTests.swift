//
//  BayerLabelTests.swift
//  EphoemerousTests
//
//  The three rules that decide which stars wear a bare Greek letter.
//

import Testing
import Foundation
@testable import Ephoemerous

@MainActor
struct BayerLabelTests {

    // MARK: - Star.bayerLetter

    /// `calculateName` emits `[Flamsteed] [Greek] Abbrev`, so the letter has
    /// to be found by token, not by position.
    @Test func bayerLetterReadsEveryNameShape() {
        #expect(Star.mockStars.first { $0.name == "α Ori" }?.bayerLetter == "α")
        #expect(Star.mockStars.first { $0.name == "β CMa" }?.bayerLetter == "β")
        #expect(Star.mockStars.first { $0.name == "γ Leo" }?.bayerLetter == "γ")
    }

    /// A star the catalogue only ever numbered has no letter to show, and
    /// neither does one it could not designate at all — both must come back
    /// nil rather than picking up the Flamsteed number or the abbreviation.
    @Test func flamsteedOnlyAndUnknownStarsHaveNoLetter() {
        let flamsteed = StarDatabase.shared.workableStars.filter { $0.bayerLetter == nil }
        #expect(!flamsteed.isEmpty)
        // Whatever came back nil must genuinely carry no Greek token.
        for star in flamsteed.prefix(200) {
            let tokens = star.name.split(separator: " ").dropLast().map(String.init)
            #expect(tokens.allSatisfy { $0.count > 1 || $0.first?.isNumber == true || $0 == "Unknown" })
        }
    }

    // MARK: - The labelled set

    /// Non-empty, and small enough to stay a whisper: these are drawn one
    /// glyph per star with no declutter pass, so a runaway set would carpet
    /// the sky.
    @Test func figureStarsAreLettered() {
        let set = SkyFrame.bayerFigureStars
        #expect(!set.isEmpty)
        #expect(set.count < 700)
    }

    /// Rule one: only stars a stick-figure actually touches.
    @Test func everyLetteredStarIsOnAFigure() {
        let touched = Set(ConstellationLines.shared.figureStars.map(\.id))
        #expect(SkyFrame.bayerFigureStars.allSatisfy { touched.contains($0.id) })
    }

    /// Rule two: a star with a name of its own already gets a full POI
    /// label — lettering it too would put two marks on one dot.
    @Test func namedStarsAreNeverLettered() {
        #expect(SkyFrame.bayerFigureStars.allSatisfy { $0.properName == nil })
    }

    /// Rule three: something to actually draw.
    @Test func everyLetteredStarHasALetter() {
        #expect(SkyFrame.bayerFigureStars.allSatisfy { $0.bayerLetter != nil })
    }

    /// The set is deduplicated — a star carrying several segments is one
    /// entry, or it would be drawn (and blended) on top of itself.
    @Test func letteredStarsAreUnique() {
        let ids = SkyFrame.bayerFigureStars.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
