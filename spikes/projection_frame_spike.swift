// Phase 0 spike — THROWAWAY. Run: `swift spikes/projection_frame_spike.swift`
//
// Question: is the clock (.northSouth) → travel (.userLocation) projection
// difference a single PROPER rotation of the sky (slerp-able, warp-free),
// or does it include a reflection / non-rigid part?
//
// Method: reimplement EProjection.project + SIMD3.baseVectors EXACTLY as in
// the app (zero app deps). For each mode the gnomonic projection is the
// identical function expressed in that mode's own orthonormal triad
// T = [e1 | e2 | O] (P = -O in both modes — verified from the source).
// Two identical gnomonic functions in different triads are related by the
// rigid map that aligns the triads:
//
//     travelScreen(Q) == clockScreen(R · Q),  R = -(Mc · Mtᵀ)
//
// (the -1 folds in travel's `-Q` input). R is orthogonal by construction;
// the ONLY open question is det(R): +1 ⇒ proper rotation ⇒ quaternion
// slerp identity→R gives exact endpoints + rigid continuity ⇒ plan valid.
// -1 ⇒ reflection ⇒ need a screen-axis sign fix first; the spike tests
// that variant too.

import Foundation

typealias V = [Double]   // length 3
typealias M = [[Double]] // 3x3 row-major

func dot(_ a: V, _ b: V) -> Double { a[0]*b[0] + a[1]*b[1] + a[2]*b[2] }
func cross(_ a: V, _ b: V) -> V {
    [a[1]*b[2] - a[2]*b[1], a[2]*b[0] - a[0]*b[2], a[0]*b[1] - a[1]*b[0]]
}
func sub(_ a: V, _ b: V) -> V { [a[0]-b[0], a[1]-b[1], a[2]-b[2]] }
func add(_ a: V, _ b: V) -> V { [a[0]+b[0], a[1]+b[1], a[2]+b[2]] }
func scale(_ a: V, _ s: Double) -> V { [a[0]*s, a[1]*s, a[2]*s] }
func norm(_ a: V) -> Double { (dot(a, a)).squareRoot() }
func normalize(_ a: V) -> V { scale(a, 1.0 / norm(a)) }

func spherePoint(latDeg: Double, lonDeg: Double) -> V {
    let lat = latDeg * .pi / 180, lon = lonDeg * .pi / 180
    return [cos(lat)*cos(lon), cos(lat)*sin(lon), sin(lat)]
}

// EXACT port of SIMD3.baseVectors()
func baseVectors(_ P: V) -> (e1: V, e2: V) {
    let north: V = [0, 0, 1]
    var e1 = cross(cross(P, north), P)
    if dot(e1, e1) < 1e-10 { e1 = [1, 0, 0] }
    e1 = normalize(e1)
    let e2 = normalize(cross(P, e1))
    return (e1, e2)
}

// EXACT port of EProjection.project(_:origin:plane:) -> CGPoint(x:v, y:u)
func project(_ Q: V, origin O: V, plane P: V) -> (x: Double, y: Double)? {
    let PdotO = dot(P, O), PdotQ = dot(P, Q)
    let denom = PdotQ - PdotO
    if abs(denom) <= 1e-10 { return nil }
    let t = (1.0 - PdotO) / denom
    if t <= 0 { return nil }
    let X = add(O, scale(sub(Q, O), t))
    let delta = sub(X, P)
    let (e1, e2) = baseVectors(P)
    return (x: dot(delta, e2), y: dot(delta, e1))
}

// Mode mappings, exactly as the app calls them.
let nVec: V = [0, 0, 1]            // .north
let sVec: V = [0, 0, -1]           // .south
func clockScreen(_ Q: V) -> (x: Double, y: Double)? {
    project(Q, origin: nVec, plane: sVec)            // mode == .northSouth
}
func travelScreen(_ Q: V, originVec O: V) -> (x: Double, y: Double)? {
    project(scale(Q, -1), origin: O, plane: scale(O, -1))  // .userLocation, -Q, P=-O
}

// Triad (columns e1,e2,O) for a center O with P = -O.
func triadColumns(centerO O: V) -> M {
    let (e1, e2) = baseVectors(scale(O, -1))
    // rows so that M·w applies the matrix; columns are e1,e2,O
    return [[e1[0], e2[0], O[0]],
            [e1[1], e2[1], O[1]],
            [e1[2], e2[2], O[2]]]
}

func matVec(_ A: M, _ v: V) -> V {
    [A[0][0]*v[0]+A[0][1]*v[1]+A[0][2]*v[2],
     A[1][0]*v[0]+A[1][1]*v[1]+A[1][2]*v[2],
     A[2][0]*v[0]+A[2][1]*v[1]+A[2][2]*v[2]]
}
func transpose(_ A: M) -> M {
    [[A[0][0],A[1][0],A[2][0]],
     [A[0][1],A[1][1],A[2][1]],
     [A[0][2],A[1][2],A[2][2]]]
}
func matMul(_ A: M, _ B: M) -> M {
    var C: M = [[0,0,0],[0,0,0],[0,0,0]]
    for i in 0..<3 { for j in 0..<3 {
        C[i][j] = A[i][0]*B[0][j] + A[i][1]*B[1][j] + A[i][2]*B[2][j]
    } }
    return C
}
func det3(_ A: M) -> Double {
    A[0][0]*(A[1][1]*A[2][2]-A[1][2]*A[2][1])
  - A[0][1]*(A[1][0]*A[2][2]-A[1][2]*A[2][0])
  + A[0][2]*(A[1][0]*A[2][1]-A[1][1]*A[2][0])
}
func scaleM(_ A: M, _ s: Double) -> M { A.map { $0.map { $0 * s } } }

// Rotation matrix for `angle` about unit `axis` (Rodrigues).
func axisAngle(_ axis: V, _ angle: Double) -> M {
    let u = normalize(axis)
    let c = cos(angle), s = sin(angle), t = 1 - c
    let (x, y, z) = (u[0], u[1], u[2])
    return [[t*x*x+c,   t*x*y-s*z, t*x*z+s*y],
            [t*x*y+s*z, t*y*y+c,   t*y*z-s*x],
            [t*x*z-s*y, t*y*z+s*x, t*z*z+c  ]]
}
// Proper-rotation matrix → (axis, angle). Identity-safe.
func toAxisAngle(_ R: M) -> (axis: V, angle: Double) {
    let tr = R[0][0] + R[1][1] + R[2][2]
    let cosA = max(-1, min(1, (tr - 1) / 2))
    let angle = acos(cosA)
    if angle < 1e-9 { return ([0,0,1], 0) }
    if abs(angle - .pi) < 1e-6 {
        // 180°: axis from the largest diagonal of (R+I)/2
        let xx=(R[0][0]+1)/2, yy=(R[1][1]+1)/2, zz=(R[2][2]+1)/2
        var ax: V = [xx.squareRoot(), yy.squareRoot(), zz.squareRoot()]
        if xx >= yy && xx >= zz { ax = [ax[0], (R[0][1])/(2*ax[0]), (R[0][2])/(2*ax[0])] }
        return (normalize(ax), .pi)
    }
    let ax: V = [R[2][1]-R[1][2], R[0][2]-R[2][0], R[1][0]-R[0][1]]
    return (normalize(ax), angle)
}

func screenViaRotatedClock(_ Q: V, _ Rmat: M) -> (x: Double, y: Double)? {
    clockScreen(matVec(Rmat, Q))
}

// Random unit vector valid (non-nil) in BOTH modes for a given origin.
var seed: UInt64 = 0x9E3779B97F4A7C15
func rnd() -> Double { // xorshift → [0,1)
    seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
    return Double(seed % 1_000_000) / 1_000_000.0
}
func randomDir() -> V {
    let z = 2*rnd() - 1, ph = 2 * .pi * rnd(), r = (1 - z*z).squareRoot()
    return [r*cos(ph), r*sin(ph), z]
}

func evaluate(latDeg: Double, lonDeg: Double) {
    let O = spherePoint(latDeg: latDeg, lonDeg: lonDeg)
    let Mc = triadColumns(centerO: nVec)          // clock frame
    let Mt = triadColumns(centerO: O)             // travel frame
    let g  = matMul(Mc, transpose(Mt))            // aligns travel triad → clock triad
    let R  = scaleM(g, -1)                        // fold travel's `-Q`

    let dC = det3(Mc), dT = det3(Mt), dR = det3(R)

    // Residual: does clockScreen(R·Q) reproduce travelScreen(Q)?
    var maxErr = 0.0, n = 0
    for _ in 0..<20000 {
        let Q = randomDir()
        guard let a = travelScreen(Q, originVec: O),
              let b = screenViaRotatedClock(Q, R) else { continue }
        maxErr = max(maxErr, max(abs(a.x-b.x), abs(a.y-b.y))); n += 1
    }

    // Handedness-fixed variant: negate travel's screen-x, re-derive.
    // Equivalent to flipping e2 sign in the travel triad (column 1).
    var MtF = Mt; for i in 0..<3 { MtF[i][1] = -MtF[i][1] }
    let gF = matMul(Mc, transpose(MtF)); let RF = scaleM(gF, -1)
    let dRF = det3(RF)
    var maxErrF = 0.0
    for _ in 0..<20000 {
        let Q = randomDir()
        guard let a0 = travelScreen(Q, originVec: O),
              let b  = screenViaRotatedClock(Q, RF) else { continue }
        let a = (x: -a0.x, y: a0.y)            // matching x-flip on the target
        maxErrF = max(maxErrF, max(abs(a.x-b.x), abs(a.y-b.y)))
    }

    print(String(format: "lat %.0f lon %.0f  | det Mc=%+.3f Mt=%+.3f  R: det=%+.6f resid=%.2e (n=%d)",
                  latDeg, lonDeg, dC, dT, dR, maxErr, n))
    print(String(format: "                | x-flip variant: det(R')=%+.6f resid'=%.2e", dRF, maxErrF))

    // Pick whichever variant is a proper rotation for the continuity test.
    let properR: M? = abs(dR-1) < 1e-6 ? R : (abs(dRF-1) < 1e-6 ? RF : nil)
    guard let RR = properR else { print("                | NO proper-rotation variant"); return }
    let (axis, ang) = toAxisAngle(RR)
    print(String(format: "                | rotation angle = %.2f°, axis=(%.3f,%.3f,%.3f)",
                  ang*180 / .pi, axis[0], axis[1], axis[2]))

    // Continuity: slerp identity→RR, watch sample stars move smoothly.
    let samples: [V] = [normalize([0.3,0.2,0.9]), normalize([1,0,0.2]),
                        normalize([0,1,0.1]), normalize([0.5,-0.5,0.7])]
    for (k, Q) in samples.enumerated() {
        var line = "                | star\(k): "
        for f in stride(from: 0.0, through: 1.0, by: 0.25) {
            let Rf = axisAngle(axis, f * ang)
            if let p = screenViaRotatedClock(Q, Rf) {
                line += String(format: "[%.0f%% %+.2f,%+.2f] ", f*100, p.x, p.y)
            } else { line += "[\(Int(f*100))% nil] " }
        }
        print(line)
    }
    // Endpoint exactness check (frac 0 == clock, frac 1 == travel).
    var e0 = 0.0, e1 = 0.0
    for _ in 0..<5000 {
        let Q = randomDir()
        if let c = clockScreen(Q), let p0 = screenViaRotatedClock(Q, axisAngle(axis, 0)) {
            e0 = max(e0, max(abs(c.x-p0.x), abs(c.y-p0.y)))
        }
        if let tv = travelScreen(Q, originVec: O),
           let p1 = screenViaRotatedClock(Q, axisAngle(axis, ang)) {
            // (when the proper variant is the x-flip one, compare flipped)
            let target = abs(dR-1) < 1e-6 ? tv : (x: -tv.x, y: tv.y)
            e1 = max(e1, max(abs(target.x-p1.x), abs(target.y-p1.y)))
        }
    }
    print(String(format: "                | endpoint exactness: blend0 vs clock=%.2e, blend1 vs travel=%.2e",
                  e0, e1))
}

// Dissolve-hide check: worst case (lat 51, 180°). Does the content that is
// INSIDE the clock clip disc stay bounded & smooth across the whole
// rotation (⇒ keeping the disc clock-sized until the end hides the
// blow-up), or do in-disc stars excurse out and back (⇒ visible streak)?
func dissolveHideCheck() {
    let O = spherePoint(latDeg: 51, lonDeg: 0)
    let Mc = triadColumns(centerO: nVec)
    var MtF = triadColumns(centerO: O); for i in 0..<3 { MtF[i][1] = -MtF[i][1] }
    let RF = scaleM(matMul(Mc, transpose(MtF)), -1)         // proper variant
    let (axis, ang) = toAxisAngle(RF)
    let discR = 2 * (3.0).squareRoot()                      // clip radius, proj units

    // Stars inside the disc at BOTH endpoints (persist through the view).
    var stars: [V] = []
    for _ in 0..<200000 {
        let Q = randomDir()
        guard let a = clockScreen(Q) else { continue }
        guard let b0 = screenViaRotatedClock(Q, RF) else { continue }
        let b = (x: -b0.x, y: b0.y)
        if (a.x*a.x+a.y*a.y).squareRoot() < discR
        && (b.x*b.x+b.y*b.y).squareRoot() < discR { stars.append(Q) }
        if stars.count >= 4000 { break }
    }
    var everLeft = 0
    var maxRofPersistent = 0.0
    var maxStepJump = 0.0
    for Q in stars {
        var prev: (x: Double, y: Double)? = nil
        var leftDisc = false
        for f in stride(from: 0.0, through: 1.0, by: 0.02) {
            let Rf = axisAngle(axis, f * ang)
            guard let p0 = screenViaRotatedClock(Q, Rf) else { leftDisc = true; continue }
            let p = (x: -p0.x, y: p0.y)
            let r = (p.x*p.x + p.y*p.y).squareRoot()
            if r > discR { leftDisc = true }
            maxRofPersistent = max(maxRofPersistent, min(r, 1e9))
            if let pv = prev { maxStepJump = max(maxStepJump,
                max(abs(p.x-pv.x), abs(p.y-pv.y))) }
            prev = p
        }
        if leftDisc { everLeft += 1 }
    }
    print("--- dissolve-hide check (lat 51, 180°, disc R=\(String(format: "%.2f", discR))) ---")
    print("persistent in-disc stars sampled: \(stars.count)")
    print(String(format: "  ever leave disc mid-rotation: %d (%.1f%%)",
                 everLeft, 100.0*Double(everLeft)/Double(max(1,stars.count))))
    print(String(format: "  max radius reached by those stars: %.2f (disc=%.2f)",
                 maxRofPersistent, discR))
    print(String(format: "  max per-2%%-step screen jump (in-units): %.3f", maxStepJump))
    print("INTERPRETATION: if ~0% ever leave and max radius ≲ disc, a")
    print("clock-sized clip held until the rotation completes hides the")
    print("blow-up entirely — the dissolve only needs to expand AFTER.")
    print("")
}

// ── Phase 2: is there a `-Q`-free equivalent of travel? ──────────────
// app travel = project(-Q, o, -o). We need a (+Q) form  project(Q, O*, P*)
// (optionally with a screen-axis sign) that reproduces it EXACTLY and is
// handedness-consistent with clock — then clock→travel is a pure centre
// slerp (.north → O*). Also report the geodesic angle .north→O* (a proxy
// for boundedness: <~80° stays well inside the gnomonic disc; ≳90° blows).
func phase2EquivalenceSearch() {
    print("── Phase 2: -Q-free travel equivalence search ──")
    func ang(_ a: V, _ b: V) -> Double { acos(max(-1,min(1,dot(a,b)))) * 180 / .pi }
    for (la, lo) in [(51.0,0.0),(0.0,90.0),(-33.0,151.0),(78.0,-20.0)] {
        let o  = spherePoint(latDeg: la, lonDeg: lo)
        let no = scale(o, -1)
        func appT(_ Q: V) -> (x: Double, y: Double)? { travelScreen(Q, originVec: o) }

        // Candidate +Q forms and screen-sign variants.
        let cands: [(String, (V) -> (x: Double, y: Double)?, V)] = [
            ("proj(Q,-o, o)        ", { project($0, origin: no, plane: o) }, no),
            ("proj(Q,-o, o) xflip  ", { project($0, origin: no, plane: o).map{(-$0.x,$0.y)} }, no),
            ("proj(Q,-o, o) yflip  ", { project($0, origin: no, plane: o).map{($0.x,-$0.y)} }, no),
            ("proj(Q, o,-o)        ", { project($0, origin: o,  plane: no) }, o),
            ("proj(Q, o,-o) xflip  ", { project($0, origin: o,  plane: no).map{(-$0.x,$0.y)} }, o),
        ]
        var best = ""; var bestErr = Double.infinity; var bestAxisDeg = 0.0
        for (name, f, Ostar) in cands {
            var mx = 0.0, n = 0
            for _ in 0..<20000 {
                let Q = randomDir()
                guard let a = appT(Q), let b = f(Q) else { continue }
                mx = max(mx, max(abs(a.x-b.x), abs(a.y-b.y))); n += 1
            }
            if n > 500 && mx < bestErr { bestErr = mx; best = name; bestAxisDeg = ang(nVec, Ostar) }
            print(String(format: "  lat %3.0f: %@ resid=%.2e (n=%d)  geo∠(.north→O*)=%.1f°",
                          la, name, mx, n, ang(nVec, Ostar)))
        }
        print(String(format: "  → best: %@ resid=%.2e  geodesic=%.1f°  %@",
                      best, bestErr, bestAxisDeg,
                      bestErr < 1e-7 ? (bestAxisDeg < 85 ? "EXACT & BOUNDED ✓"
                                                         : "exact but geodesic blows ✗")
                                     : "no exact +Q form ✗"))
        print("")
    }
}

phase2EquivalenceSearch()
print("=== Phase 0: clock↔travel projection-frame spike ===")
for (la, lo) in [(51.0, 0.0), (0.0, 90.0), (-33.0, 151.0), (78.0, -20.0)] {
    evaluate(latDeg: la, lonDeg: lo)
}
// Camera-slerp formulation: move the projection centre + a parallel-
// transported basis along the geodesic .north → originVec (P = -O), rather
// than spinning the sky about a fixed clock centre. Continuous by
// construction (no baseVectors recompute → no pole singularity).
func cameraSlerpCheck() {
    let O1 = spherePoint(latDeg: 51, lonDeg: 0)            // travel centre
    let O0 = nVec                                          // clock centre
    let (e1c, e2c) = baseVectors(sVec)                     // clock basis (P=.south)
    let axis = normalize(cross(O0, O1))
    let ang  = acos(max(-1, min(1, dot(O0, O1))))
    let discR = 2 * (3.0).squareRoot()

    func frame(_ f: Double) -> (O: V, e1: V, e2: V) {
        let Rt = axisAngle(axis, f * ang)
        return (matVec(Rt, O0), matVec(Rt, e1c), matVec(Rt, e2c))
    }
    func screen(_ Q: V, _ f: Double) -> (x: Double, y: Double)? {
        let fr = frame(f); let O = fr.O; let P = scale(O, -1)
        let PdotO = dot(P, O), PdotQ = dot(P, Q)
        let denom = PdotQ - PdotO
        if abs(denom) <= 1e-10 { return nil }
        let t = (1.0 - PdotO) / denom
        if t <= 0 { return nil }
        let X = add(O, scale(sub(Q, O), t))
        let d = sub(X, P)
        return (x: dot(d, fr.e2), y: dot(d, fr.e1))
    }

    var stars: [V] = []
    for _ in 0..<200000 {
        let Q = randomDir()
        guard let a = screen(Q, 0), let b = screen(Q, 1) else { continue }
        if (a.x*a.x+a.y*a.y).squareRoot() < discR
        && (b.x*b.x+b.y*b.y).squareRoot() < discR { stars.append(Q) }
        if stars.count >= 4000 { break }
    }
    var everLeft = 0, maxR = 0.0, maxJump = 0.0
    for Q in stars {
        var prev: (x: Double, y: Double)? = nil
        var left = false
        for f in stride(from: 0.0, through: 1.0, by: 0.02) {
            guard let p = screen(Q, f) else { left = true; continue }
            let r = (p.x*p.x+p.y*p.y).squareRoot()
            if r > discR { left = true }
            maxR = max(maxR, min(r, 1e9))
            if let pv = prev { maxJump = max(maxJump, max(abs(p.x-pv.x), abs(p.y-pv.y))) }
            prev = p
        }
        if left { everLeft += 1 }
    }
    print("--- camera-slerp check (lat 51, geodesic angle \(String(format: "%.1f", ang*180 / .pi))°) ---")
    print("persistent in-disc stars: \(stars.count)")
    print(String(format: "  ever leave disc mid-transition: %d (%.1f%%)",
                 everLeft, 100.0*Double(everLeft)/Double(max(1,stars.count))))
    print(String(format: "  max radius reached: %.3f (disc=%.2f)", maxR, discR))
    print(String(format: "  max per-2%%-step jump: %.4f", maxJump))
    print("VERDICT: ~0% leave + maxR ≲ disc ⇒ camera-slerp keeps in-disc")
    print("content bounded; 'hide with dissolve' is viable as decided.")
    print("")
}

print("")
cameraSlerpCheck()
dissolveHideCheck()
print("PASS if: a proper-rotation variant exists (det≈+1), residual≈1e-9,")
print("endpoint exactness≈1e-9, and sample stars move continuously (no jump).")
