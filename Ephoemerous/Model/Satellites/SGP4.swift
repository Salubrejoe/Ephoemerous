import Foundation
import simd

// MARK: - SGP4
// The near-Earth half of the SGP4 propagator (Vallado, Crawford, Hujsak &
// Kelso, "Revisiting Spacetrack Report #3", AIAA 2006-6753), with the
// WGS-72 constants the element sets are fitted against. Deep-space (SDP4)
// terms are deliberately absent: everything we propagate orbits in well
// under the 225-minute cut-off, and `init` refuses anything that doesn't.
//
// Output is position / velocity in km, km/s, in the TEME frame — true
// equator, mean equinox of date. For a naked-eye sky that is the same frame
// the rest of the app draws "of date" RA/Dec in (the difference is the
// equation of the equinoxes, ≲ 1.2″ of RA).
nonisolated struct SGP4: Sendable {

    // MARK: WGS-72

    static let earthRadiusKm:     Double = 6_378.135
    private static let mu:        Double = 398_600.8
    private static let xke:       Double = 60 / (earthRadiusKm * earthRadiusKm * earthRadiusKm / mu).squareRoot()
    private static let j2:        Double =  0.001_082_616
    private static let j3:        Double = -0.000_002_538_81
    private static let j4:        Double = -0.000_001_655_97
    private static let j3oj2:     Double = j3 / j2
    private static let x2o3:      Double = 2.0 / 3.0
    private static let twoPi:     Double = 2 * .pi
    private static let vkmPerSec: Double = earthRadiusKm * xke / 60

    struct State: Sendable {
        let position: SIMD3<Double>   // km, TEME
        let velocity: SIMD3<Double>   // km/s, TEME
    }

    enum Failure: Error { case deepSpace, eccentricity, semiLatusRectum, decayed }

    let elements: OrbitalElements

    // Epoch elements (radians, radians / minute).
    private let ecco, argpo, inclo, mo, nodeo, bstar, no: Double

    // Initialised secular and drag coefficients.
    private let isimp: Bool
    private let aycof, con41, cc1, cc4, cc5, d2, d3, d4, delmo, eta, argpdot, omgcof,
                sinmao, t2cof, t3cof, t4cof, t5cof, x1mth2, x7thm1, mdot, nodedot,
                xlcof, xmcof, nodecf: Double

    // MARK: Initialise

    init(_ elements: OrbitalElements) throws {
        guard elements.periodMinutes < 225 else { throw Failure.deepSpace }
        self.elements = elements

        let deg = Double.pi / 180
        ecco    = elements.eccentricity
        argpo   = elements.argOfPericenter * deg
        inclo   = elements.inclination * deg
        mo      = elements.meanAnomaly * deg
        nodeo   = elements.ascendingNode * deg
        bstar   = elements.bstar
        let noKozai = elements.meanMotion * Self.twoPi / 1440

        // initl — recover the Brouwer mean motion from the Kozai one.
        let eccsq   = ecco * ecco
        let omeosq  = 1 - eccsq
        let rteosq  = omeosq.squareRoot()
        let cosio   = cos(inclo)
        let cosio2  = cosio * cosio
        let ak      = pow(Self.xke / noKozai, Self.x2o3)
        let d1      = 0.75 * Self.j2 * (3 * cosio2 - 1) / (rteosq * omeosq)
        var del     = d1 / (ak * ak)
        let adel    = ak * (1 - del * del - del * (1.0 / 3.0 + 134 * del * del / 81))
        del         = d1 / (adel * adel)
        no          = noKozai / (1 + del)

        let ao      = pow(Self.xke / no, Self.x2o3)
        let sinio   = sin(inclo)
        let po      = ao * omeosq
        let con42   = 1 - 5 * cosio2
        con41       = -con42 - cosio2 - cosio2
        let posq    = po * po
        let rp      = ao * (1 - ecco)

        // sgp4init — atmospheric-drag and secular coefficients.
        var qzms24  = pow((120 - 78) / Self.earthRadiusKm, 4)
        var sfour   = 78 / Self.earthRadiusKm + 1
        isimp       = rp < 220 / Self.earthRadiusKm + 1
        let perige  = (rp - 1) * Self.earthRadiusKm
        if perige < 156 {
            sfour   = perige < 98 ? 20 : perige - 78
            qzms24  = pow((120 - sfour) / Self.earthRadiusKm, 4)
            sfour   = sfour / Self.earthRadiusKm + 1
        }

        let pinvsq  = 1 / posq
        let tsi     = 1 / (ao - sfour)
        eta         = ao * ecco * tsi
        let etasq   = eta * eta
        let eeta    = ecco * eta
        let psisq   = abs(1 - etasq)
        let coef    = qzms24 * pow(tsi, 4)
        let coef1   = coef / pow(psisq, 3.5)
        let cc2     = coef1 * no * (ao * (1 + 1.5 * etasq + eeta * (4 + etasq))
                    + 0.375 * Self.j2 * tsi / psisq * con41 * (8 + 3 * etasq * (8 + etasq)))
        cc1         = bstar * cc2
        let cc3     = ecco > 1e-4 ? -2 * coef * tsi * Self.j3oj2 * no * sinio / ecco : 0
        x1mth2      = 1 - cosio2
        cc4         = 2 * no * coef1 * ao * omeosq
                    * (eta * (2 + 0.5 * etasq) + ecco * (0.5 + 2 * etasq)
                       - Self.j2 * tsi / (ao * psisq)
                       * (-3 * con41 * (1 - 2 * eeta + etasq * (1.5 - 0.5 * eeta))
                          + 0.75 * x1mth2 * (2 * etasq - eeta * (1 + etasq)) * cos(2 * argpo)))
        cc5         = 2 * coef1 * ao * omeosq * (1 + 2.75 * (etasq + eeta) + eeta * etasq)

        let cosio4  = cosio2 * cosio2
        let temp1   = 1.5 * Self.j2 * pinvsq * no
        let temp2   = 0.5 * temp1 * Self.j2 * pinvsq
        let temp3   = -0.46875 * Self.j4 * pinvsq * pinvsq * no
        mdot        = no + 0.5 * temp1 * rteosq * con41
                    + 0.0625 * temp2 * rteosq * (13 - 78 * cosio2 + 137 * cosio4)
        argpdot     = -0.5 * temp1 * con42
                    + 0.0625 * temp2 * (7 - 114 * cosio2 + 395 * cosio4)
                    + temp3 * (3 - 36 * cosio2 + 49 * cosio4)
        let xhdot1  = -temp1 * cosio
        nodedot     = xhdot1 + (0.5 * temp2 * (4 - 19 * cosio2) + 2 * temp3 * (3 - 7 * cosio2)) * cosio
        omgcof      = bstar * cc3 * cos(argpo)
        xmcof       = ecco > 1e-4 ? -Self.x2o3 * coef * bstar / eeta : 0
        nodecf      = 3.5 * omeosq * xhdot1 * cc1
        t2cof       = 1.5 * cc1
        let xlden   = abs(cosio + 1) > 1.5e-12 ? 1 + cosio : 1.5e-12
        xlcof       = -0.25 * Self.j3oj2 * sinio * (3 + 5 * cosio) / xlden
        aycof       = -0.5 * Self.j3oj2 * sinio
        delmo       = pow(1 + eta * cos(mo), 3)
        sinmao      = sin(mo)
        x7thm1      = 7 * cosio2 - 1

        if isimp {
            (d2, d3, d4, t3cof, t4cof, t5cof) = (0, 0, 0, 0, 0, 0)
        } else {
            let cc1sq = cc1 * cc1
            d2        = 4 * ao * tsi * cc1sq
            let temp  = d2 * tsi * cc1 / 3
            d3        = (17 * ao + sfour) * temp
            d4        = 0.5 * temp * ao * tsi * (221 * ao + 31 * sfour) * cc1
            t3cof     = d2 + 2 * cc1sq
            t4cof     = 0.25 * (3 * d3 + cc1 * (12 * d2 + 10 * cc1sq))
            t5cof     = 0.2 * (3 * d4 + 12 * cc1 * d3 + 6 * d2 * d2 + 15 * cc1sq * (2 * d2 + cc1sq))
        }
    }

    // MARK: Propagate

    func state(at date: Date) throws -> State {
        try state(minutesSinceEpoch: elements.minutesSinceEpoch(date))
    }

    func state(minutesSinceEpoch t: Double) throws -> State {
        // Secular gravity and drag.
        let xmdf   = mo + mdot * t
        let argpdf = argpo + argpdot * t
        let nodedf = nodeo + nodedot * t
        let t2     = t * t
        var argpm  = argpdf
        var mm     = xmdf
        var nodem  = nodedf + nodecf * t2
        var tempa  = 1 - cc1 * t
        var tempe  = bstar * cc4 * t
        var templ  = t2cof * t2

        if !isimp {
            let delomg = omgcof * t
            let delm   = xmcof * (pow(1 + eta * cos(xmdf), 3) - delmo)
            let temp   = delomg + delm
            mm         = xmdf + temp
            argpm      = argpdf - temp
            let t3     = t2 * t
            let t4     = t3 * t
            tempa     -= d2 * t2 + d3 * t3 + d4 * t4
            tempe     += bstar * cc5 * (sin(mm) - sinmao)
            templ     += t3cof * t3 + t4 * (t4cof + t * t5cof)
        }

        let am = pow(Self.xke / no, Self.x2o3) * tempa * tempa
        let nm = Self.xke / pow(am, 1.5)
        var em = ecco - tempe
        guard em < 1, em >= -0.001 else { throw Failure.eccentricity }
        em = max(em, 1e-6)

        mm        += no * templ
        var xlm    = mm + argpm + nodem
        nodem      = nodem.truncatingRemainder(dividingBy: Self.twoPi)
        argpm      = argpm.truncatingRemainder(dividingBy: Self.twoPi)
        xlm        = xlm.truncatingRemainder(dividingBy: Self.twoPi)
        mm         = (xlm - argpm - nodem).truncatingRemainder(dividingBy: Self.twoPi)

        // Long-period periodics.
        let sinip  = sin(inclo)
        let cosip  = cos(inclo)
        let axnl   = em * cos(argpm)
        var temp   = 1 / (am * (1 - em * em))
        let aynl   = em * sin(argpm) + temp * aycof
        let xl     = mm + argpm + nodem + temp * xlcof * axnl

        // Kepler's equation.
        let u      = (xl - nodem).truncatingRemainder(dividingBy: Self.twoPi)
        var eo1    = u
        var tem5   = 9999.9
        var sineo1 = 0.0
        var coseo1 = 0.0
        var ktr    = 1
        while abs(tem5) >= 1e-12, ktr <= 10 {
            sineo1 = sin(eo1)
            coseo1 = cos(eo1)
            tem5   = (u - aynl * coseo1 + axnl * sineo1 - eo1) / (1 - coseo1 * axnl - sineo1 * aynl)
            tem5   = max(-0.95, min(0.95, tem5))
            eo1   += tem5
            ktr   += 1
        }

        // Short-period preliminaries.
        let ecose  = axnl * coseo1 + aynl * sineo1
        let esine  = axnl * sineo1 - aynl * coseo1
        let el2    = axnl * axnl + aynl * aynl
        let pl     = am * (1 - el2)
        guard pl >= 0 else { throw Failure.semiLatusRectum }

        let rl     = am * (1 - ecose)
        let rdotl  = am.squareRoot() * esine / rl
        let rvdotl = pl.squareRoot() / rl
        let betal  = (1 - el2).squareRoot()
        temp       = esine / (1 + betal)
        let sinu   = am / rl * (sineo1 - aynl - axnl * temp)
        let cosu   = am / rl * (coseo1 - axnl + aynl * temp)
        var su     = atan2(sinu, cosu)
        let sin2u  = (cosu + cosu) * sinu
        let cos2u  = 1 - 2 * sinu * sinu
        temp       = 1 / pl
        let temp1  = 0.5 * Self.j2 * temp
        let temp2  = temp1 * temp

        // Short-period periodics.
        let mrt    = rl * (1 - 1.5 * temp2 * betal * con41) + 0.5 * temp1 * x1mth2 * cos2u
        su        -= 0.25 * temp2 * x7thm1 * sin2u
        let xnode  = nodem + 1.5 * temp2 * cosip * sin2u
        let xinc   = inclo + 1.5 * temp2 * cosip * sinip * cos2u
        let mvt    = rdotl - nm * temp1 * x1mth2 * sin2u / Self.xke
        let rvdot  = rvdotl + nm * temp1 * (x1mth2 * cos2u + 1.5 * con41) / Self.xke
        guard mrt >= 1 else { throw Failure.decayed }

        // Orientation vectors.
        let sinsu  = sin(su),    cossu = cos(su)
        let snod   = sin(xnode), cnod  = cos(xnode)
        let sini   = sin(xinc),  cosi  = cos(xinc)
        let xmx    = -snod * cosi
        let xmy    =  cnod * cosi
        let uvec   = SIMD3(xmx * sinsu + cnod * cossu,
                           xmy * sinsu + snod * cossu,
                           sini * sinsu)
        let vvec   = SIMD3(xmx * cossu - cnod * sinsu,
                           xmy * cossu - snod * sinsu,
                           sini * cossu)

        return State(position: mrt * uvec * Self.earthRadiusKm,
                     velocity: (mvt * uvec + rvdot * vvec) * Self.vkmPerSec)
    }
}
