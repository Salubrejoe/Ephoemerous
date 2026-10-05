import SwiftUI
import LoreKit

// MARK: - Star shape
// Every star on the field wears the pentagon squircle, the badge grammar
// at dot size. Built ONCE, at unit size, then scaled and moved onto each
// star with an affine transform.
//
// Why: `Squircle.path(in:)` samples 241 rim points, each with two `pow`s
// and a `cos`/`sin`. Thousands of stars per redraw cost ~45 ms on a Mac —
// three dropped frames every time a gesture settled, which is why the
// field used to be plain circles. Transforming one cached path costs less
// than building an ellipse. At 1–3 pt radius, 25 rim points is still more
// than the pixels can show.
extension Artist {

    /// Corners and bulge of the star mark — the named-star pentagon's.
    var starCorners: Int     { 5 }
    var starBulge:   CGFloat { poiBadgeBulge }

    /// The star mark centred on `p`, `r` from centre to rim.
    func starPath(at p: CGPoint, radius r: CGFloat) -> Path {
        StarShape.unit.applying(CGAffineTransform(a: r, b: 0, c: 0, d: r, tx: p.x, ty: p.y))
    }

    /// True when a dot shape is the star mark, so it can take the cached path.
    func isStarShape(corners: Int, bulge: CGFloat) -> Bool {
        corners == starCorners && bulge == starBulge
    }
}

private enum StarShape {
    /// Rim samples — enough for a dot, a tenth of `Squircle`'s default.
    static let segments = 25

    /// The star mark inscribed in the unit circle, centred on the origin.
    static let unit: Path = {
        let a     = Artist.shared
        let rim   = Squircle(corners: a.starCorners, bulge: a.starBulge)
            .vertices(in: CGRect(x: -1, y: -1, width: 2, height: 2), segments: segments)
        var path  = Path()
        path.addLines(rim)
        path.closeSubpath()
        return path
    }()
}
