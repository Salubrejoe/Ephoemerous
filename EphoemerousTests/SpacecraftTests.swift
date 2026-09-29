//
//  SpacecraftTests.swift
//  EphoemerousTests
//
//  The orbit engine behind the ISS / Hubble / Webb pins: the propagator
//  against its published reference, the parsers against real payloads,
//  and the pass finder against geometry that has to hold.
//

import Testing
import Foundation
import simd
@testable import Ephoemerous

struct SpacecraftTests {

    // MARK: - SGP4

    /// Vallado's verification satellite 00005 (tcppver.out). Matching it to
    /// the metre is the whole proof that the near-Earth terms are right.
    @Test func sgp4MatchesValladoReference() throws {
        let epoch = Date(timeIntervalSince1970: 946_684_800 + (179.784_950_62 - 1) * 86_400)
        let elements = OrbitalElements(name:            "00005",
                                       noradID:         5,
                                       epoch:           epoch,
                                       meanMotion:      10.824_191_57,
                                       eccentricity:    0.185_966_7,
                                       inclination:     34.2682,
                                       ascendingNode:   348.7242,
                                       argOfPericenter: 331.7664,
                                       meanAnomaly:     19.3264,
                                       bstar:           0.280_98e-4)
        let orbit = try SGP4(elements)

        let t0 = try orbit.state(minutesSinceEpoch: 0)
        #expect(simd_distance(t0.position, SIMD3(7022.465_292_66, -1400.082_967_55, 0.039_951_55)) < 1e-3)
        #expect(simd_distance(t0.velocity, SIMD3(1.893_841_015, 6.405_893_759, 4.534_807_250)) < 1e-6)

        let t360 = try orbit.state(minutesSinceEpoch: 360)
        #expect(simd_distance(t360.position, SIMD3(-7154.031_202_02, -3783.176_825_04, -3536.194_122_94)) < 1e-3)
        #expect(simd_distance(t360.velocity, SIMD3(4.741_887_409, -4.151_817_765, -2.093_935_425)) < 1e-6)
    }

    /// Deep-space orbits need SDP4, which we don't carry — refuse, don't guess.
    @Test func sgp4RefusesDeepSpaceOrbits() {
        let geo = OrbitalElements(name: "GEO", noradID: 1, epoch: .now, meanMotion: 1.0027,
                                  eccentricity: 0.0002, inclination: 0.05, ascendingNode: 0,
                                  argOfPericenter: 0, meanAnomaly: 0, bstar: 0)
        #expect(throws: SGP4.Failure.self) { try SGP4(geo) }
    }

    // MARK: - Parsing

    @Test func celestrakOMMDecodes() throws {
        let json = """
        [{"OBJECT_NAME":"ISS (ZARYA)","OBJECT_ID":"1998-067A","EPOCH":"2026-09-28T11:09:16.121952",
          "MEAN_MOTION":15.48680135,"ECCENTRICITY":0.00071596,"INCLINATION":51.6312,
          "RA_OF_ASC_NODE":148.9632,"ARG_OF_PERICENTER":198.226,"MEAN_ANOMALY":161.8473,
          "EPHEMERIS_TYPE":0,"CLASSIFICATION_TYPE":"U","NORAD_CAT_ID":25544,"ELEMENT_SET_NO":999,
          "REV_AT_EPOCH":58776,"BSTAR":0.00011848,"MEAN_MOTION_DOT":6.013e-5,"MEAN_MOTION_DDOT":0}]
        """
        let e = try #require(try OrbitalElements.decoder.decode([OrbitalElements].self, from: Data(json.utf8)).first)
        #expect(e.noradID == 25_544)
        #expect(abs(e.periodMinutes - 92.98) < 0.01)
        // 2026-09-28 11:09:16.121952 UTC
        #expect(abs(e.epoch.timeIntervalSince1970 - 1_790_593_756.121_952) < 1e-3)
    }

    @Test func horizonsTableParsesAndInterpolates() throws {
        let text = """
        *******************************************************************************
        $$SOE
         2026-Sep-29 00:00, , ,    18.93386,    19.10778,  0.00857661514011,  0.0932031,
         2026-Sep-30 00:00, , ,    21.09342,    19.53712,  0.00863115212831,  0.0956083,
        $$EOE
        *******************************************************************************
        """
        let table = try #require(HorizonsEphemeris.parse(text))
        #expect(table.rows.count == 2)

        let noon = try #require(table.coverage).lowerBound.addingTimeInterval(43_200)
        let range = try #require(table.rangeKm(at: noon))
        #expect(abs(range - 0.008_604 * 149_597_870.7) < 2_000)     // ~1.287 million km

        // Outside the table there is no position, rather than an extrapolated guess.
        #expect(table.rangeKm(at: noon.addingTimeInterval(10 * 86_400)) == nil)
    }

    // MARK: - Geometry

    /// A craft directly above the observer must read ~90° altitude, and its
    /// direction must be the observer's own zenith.
    @Test func overheadCraftLooksStraightUp() {
        let observer = SatelliteSky.Observer(latitudeDegrees: -33.8688, longitudeDegrees: 151.2093)
        let date     = Date(timeIntervalSince1970: 1_790_640_000)
        let up       = SatelliteSky.rotateZ(observer.enuBasis.up, by: SatelliteSky.gmst(date))
        let site     = SatelliteSky.rotateZ(observer.earthFixedKm, by: SatelliteSky.gmst(date))
        let look     = SatelliteSky.look(at: site + up * 420, from: observer, date: date)
        #expect(look.altitude * 180 / .pi > 89.9)
        #expect(abs(look.rangeKm - 420) < 1e-6)
        #expect(simd_dot(look.direction, up) > 0.999_99)
    }

    @Test func earthShadowHidesTheNightSide() {
        let sun = SIMD3<Double>(1, 0, 0)
        #expect( SatelliteSky.isSunlit(SIMD3(7_000, 0, 0),  sun: sun))    // day side
        #expect(!SatelliteSky.isSunlit(SIMD3(-7_000, 0, 0), sun: sun))    // straight behind Earth
        #expect( SatelliteSky.isSunlit(SIMD3(-7_000, 0, 7_000), sun: sun)) // behind, but clear of the umbra
    }

    @Test func compassPointsWrap() {
        #expect(SpacecraftFacts.compassPoint(0) == "N")
        #expect(SpacecraftFacts.compassPoint(.pi / 2) == "E")
        #expect(SpacecraftFacts.compassPoint(2 * .pi - 0.01) == "N")
    }

    // MARK: - Passes

    /// Every predicted pass rises before it peaks before it sets, peaks above
    /// the horizon, and its visible stretch sits inside it.
    @Test func passesAreWellFormed() throws {
        let epoch = Date(timeIntervalSince1970: 1_790_593_756)
        let iss   = OrbitalElements(name: "ISS", noradID: 25_544, epoch: epoch, meanMotion: 15.486_801_35,
                                    eccentricity: 0.000_715_96, inclination: 51.6312, ascendingNode: 148.9632,
                                    argOfPericenter: 198.226, meanAnomaly: 161.8473, bstar: 0.000_118_48)
        let observer = SatelliteSky.Observer(latitudeDegrees: 51.5, longitudeDegrees: -0.1)
        let passes   = SatellitePassPredictor.passes(of: try SGP4(iss), standardMagnitude: -1.8,
                                                     from: observer, start: epoch, span: 3 * 86_400)
        // A 51.6° orbit crosses London's sky several times a day.
        #expect(passes.count > 10)
        for pass in passes {
            #expect(pass.rise.date < pass.peak.date || pass.rise.date == pass.peak.date)
            #expect(pass.peak.date <= pass.set.date)
            #expect(pass.peak.altitude > 0)
            if let start = pass.visibleStart, let end = pass.visibleEnd {
                #expect(start.date >= pass.rise.date && end.date <= pass.set.date)
                #expect(start.altitude >= SatellitePassPredictor.minimumVisibleAltitude)
            }
        }
    }
}
