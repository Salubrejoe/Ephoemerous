//
//  DomainMappingTests.swift
//  EphoemerousTests
//
//  Pure domain mappings: moon-phase bucketing, constellation entity →
//  glyph, and the latitude geometry for "ever visible" / circumpolar.
//

import Testing
import Foundation
@testable import Ephoemerous

struct DomainMappingTests {

    private let artist = EArtist.shared

    // MARK: - moonPhaseSymbol (illuminated fraction → phase glyph)

    @Test func moonPhaseBucketBoundaries() {
        #expect(artist.moonPhaseSymbol(fraction: 0.00) == .moonNew)
        #expect(artist.moonPhaseSymbol(fraction: 0.02) == .moonNew)
        #expect(artist.moonPhaseSymbol(fraction: 0.03) == .moonWaxingCrescent)  // boundary
        #expect(artist.moonPhaseSymbol(fraction: 0.10) == .moonWaxingCrescent)
        #expect(artist.moonPhaseSymbol(fraction: 0.22) == .moonFirstQuarter)    // boundary
        #expect(artist.moonPhaseSymbol(fraction: 0.30) == .moonFirstQuarter)
        #expect(artist.moonPhaseSymbol(fraction: 0.47) == .moonWaxingGibbous)   // boundary
        #expect(artist.moonPhaseSymbol(fraction: 0.60) == .moonWaxingGibbous)
        #expect(artist.moonPhaseSymbol(fraction: 0.78) == .moonFull)            // boundary
        #expect(artist.moonPhaseSymbol(fraction: 1.00) == .moonFull)
    }

    // MARK: - constellationEntitySymbol (exhaustive)

    @Test func entitySymbolMapping() {
        #expect(artist.constellationEntitySymbol(.hero)       == .entityHero)
        #expect(artist.constellationEntitySymbol(.animal)     == .entityAnimal)
        #expect(artist.constellationEntitySymbol(.creature)   == .entityCreature)
        #expect(artist.constellationEntitySymbol(.object)     == .entityObject)
        #expect(artist.constellationEntitySymbol(.instrument) == .entityInstrument)
        #expect(artist.constellationEntitySymbol(.deity)      == .entityDeity)
        #expect(artist.constellationEntitySymbol(.none)       == .entityFallback)
    }

    // MARK: - "ever visible": |observerLat − dec| < 90 + margin(25) = 115

    @Test func everVisibleWithinMargin() {
        #expect(artist.constellationEverVisible(decDegrees:   0, observerLatitude: 51)) // 51
        #expect(artist.constellationEverVisible(decDegrees: -40, observerLatitude: 51)) // 91
        #expect(!artist.constellationEverVisible(decDegrees: -80, observerLatitude: 51)) // 131
    }

    @Test func everVisibleBoundaryIsStrict() {
        // |51 − (−64)| = 115 exactly → not visible (strict <)
        #expect(!artist.constellationEverVisible(decDegrees: -64.0, observerLatitude: 51))
        #expect(artist.constellationEverVisible(decDegrees: -63.9, observerLatitude: 51))
    }

    // MARK: - circumpolar (never sets at the observer's latitude)

    @Test func circumpolarNorthernObserver() {
        // lat 51 → dec ≥ 90 − 51 = 39 never sets
        #expect(artist.constellationCircumpolar(decDegrees: 40, observerLatitude: 51))
        #expect(!artist.constellationCircumpolar(decDegrees: 38, observerLatitude: 51))
    }

    @Test func circumpolarSouthernObserver() {
        // lat −33 → dec ≤ −(90 + (−33)) = −57 never sets
        #expect(artist.constellationCircumpolar(decDegrees: -60, observerLatitude: -33))
        #expect(!artist.constellationCircumpolar(decDegrees: -50, observerLatitude: -33))
    }
}
