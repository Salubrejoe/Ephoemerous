import SwiftUI
import simd

enum EMoonPosition {
    static func vector(for date: Date, siderealOffset: Angle) -> (vec: SIMD3<Double>, ra: Double, dec: Double) {
        let T = EPrecession.julianCenturies(from: date)
        let deg = Double.pi / 180.0
        let L0 = (218.3164477 + 481267.88123421 * T).truncatingRemainder(dividingBy: 360) * deg
        let M  = (134.9633964 + 477198.8676313  * T).truncatingRemainder(dividingBy: 360) * deg
        let Ms = (357.5291092 +  35999.0502909  * T).truncatingRemainder(dividingBy: 360) * deg
        let F  = (93.2720950  + 483202.0175233  * T).truncatingRemainder(dividingBy: 360) * deg
        let D  = (297.8501921 + 445267.1114034  * T).truncatingRemainder(dividingBy: 360) * deg
        var lam = L0 / deg
        lam += 6.288774 * sin(M);    lam += 1.274027 * sin(2*D - M)
        lam += 0.658314 * sin(2*D);  lam += 0.213618 * sin(2*M)
        lam -= 0.185116 * sin(Ms);   lam -= 0.114332 * sin(2*F)
        lam += 0.058793 * sin(2*D - 2*M); lam += 0.057066 * sin(2*D - Ms - M)
        lam += 0.053322 * sin(2*D + M);   lam += 0.045758 * sin(2*D - Ms)
        lam -= 0.040923 * sin(Ms - M);    lam -= 0.034720 * sin(D)
        lam -= 0.030383 * sin(Ms + M)
        var bet = 0.0
        bet += 5.128122 * sin(F);    bet += 0.280602 * sin(M + F)
        bet += 0.277693 * sin(M - F); bet += 0.173237 * sin(2*D - F)
        bet += 0.055413 * sin(2*D + F - M); bet += 0.046271 * sin(2*D - F - M)
        bet += 0.032573 * sin(2*D + F)
        let lr = lam * deg; let br = bet * deg; let eps = 23.4393 * deg
        let x = cos(br) * cos(lr)
        let y = cos(br) * sin(lr) * cos(eps) - sin(br) * sin(eps)
        let z = cos(br) * sin(lr) * sin(eps) + sin(br) * cos(eps)
        // RA / Dec before sidereal rotation
        let ra  = atan2(y, x) * 180.0 / .pi
        let dec = asin(max(-1, min(1, z))) * 180.0 / .pi
        let vec = SIMD3<Double>(x, y, z).sidereallyRotated(by: siderealOffset)
        return (vec, ra < 0 ? ra + 360 : ra, dec)
    }
    static func illuminatedFraction(for date: Date) -> Double {
        let T = EPrecession.julianCenturies(from: date)
        let deg = Double.pi / 180.0
        let D  = (297.8501921 + 445267.1114034 * T).truncatingRemainder(dividingBy: 360) * deg
        let M  = (134.9633964 + 477198.8676313 * T).truncatingRemainder(dividingBy: 360) * deg
        let Ms = (357.5291092 +  35999.0502909 * T).truncatingRemainder(dividingBy: 360) * deg
        let i  = 180.0 - D/deg - 6.289*sin(M) + 2.100*sin(Ms) - 1.274*sin(2*D-M) - 0.658*sin(2*D) - 0.214*sin(2*M) - 0.110*sin(D)
        return (1.0 + cos(i * deg)) / 2.0
    }
}

struct EMoonLayer: EGridLayer {
    func draw(in dc: inout EGraphicContext) {
        let (moonVec, ra, dec) = EMoonPosition.vector(
            for: dc.state.observationDate,
            siderealOffset: dc.state.precessedSiderealOffset
        )
        let raH = ra / 15.0
        print(String(format: "Moon   RA: %6.2fh  Dec: %+7.2fdeg", raH, dec))
        guard let projected = EProjection.project(
            moonVec,
            origin: dc.state.nsProjection.origin,
            plane: dc.state.nsProjection.plane
        ) else { return }
        
        let sc = dc.toScreen(projected)
        guard dc.onScreen(sc, margin: 40) else { return }
        let fraction = EMoonPosition.illuminatedFraction(for: dc.state.observationDate)
        let baseRadius: CGFloat = 5
        let glowRadius: CGFloat = baseRadius * 3.5
        dc.ctx.fill(Path(ellipseIn: CGRect(x: sc.x-glowRadius, y: sc.y-glowRadius, width: glowRadius*2, height: glowRadius*2)),
            with: .radialGradient(Gradient(stops: [.init(color: .white.opacity(0.25*fraction), location: 0), .init(color: .white.opacity(0), location: 1)]), center: sc, startRadius: 0, endRadius: glowRadius))
        dc.ctx.fill(Path(ellipseIn: CGRect(x: sc.x-baseRadius, y: sc.y-baseRadius, width: baseRadius*2, height: baseRadius*2)), with: .color(.gray.opacity(0.55)))
        let shift = baseRadius * CGFloat(1.0 - 2.0 * fraction)
        var clipped = dc.ctx
        clipped.clip(to: Path(ellipseIn: CGRect(x: sc.x-baseRadius, y: sc.y-baseRadius, width: baseRadius*2, height: baseRadius*2)))
        clipped.fill(Path(ellipseIn: CGRect(x: sc.x-baseRadius+shift, y: sc.y-baseRadius, width: baseRadius*2, height: baseRadius*2)), with: .color(.white.opacity(0.92)))
        dc.ctx.stroke(Path(ellipseIn: CGRect(x: sc.x-baseRadius, y: sc.y-baseRadius, width: baseRadius*2, height: baseRadius*2)), with: .color(.white.opacity(0.4)), lineWidth: 0.5)
        let label = Text("Moon").font(.system(size: 9, weight: .medium)).foregroundStyle(Color.white.opacity(0.6))
//        dc.ctx.draw(label, at: CGPoint(x: sc.x+baseRadius+5, y: sc.y), anchor: .leading)
    }
}
