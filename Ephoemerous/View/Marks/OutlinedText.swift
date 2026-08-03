import SwiftUI
import UIKit
import CoreText
import LoreKit
import WidgetKit


// MARK: - OutlinedText
// A name with a REAL outline: CoreText hands us each glyph's CGPath, we
// union them into one `Path` and stroke it (the casing) under a fill —
// a true vector edge, crisp at any size, instead of the blobby 8-copy
// stamp. One stroke + one fill, no per-glyph blur.
//
// The glyph path is cached by (text, size): the Sun label re-evaluates
// every pinch frame (its counter-scale), and re-laying-out CoreText each
// frame — per label, once we have many — would be the cost. Cache makes
// the per-frame path a dictionary hit.
struct OutlinedText: View {
    let text:      String
    let fill:      Color
    let stroke:    Color
    var lineWidth: CGFloat = 1.5
    let font:      UIFont

    /// See `POILabelView.isMasked`. The casing is a dark halo drawn to lift
    /// text off a night sky; under a tinted / "Clear" theme it is repainted
    /// as a WHITE halo and smears the glyphs. Dropped there.
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    private var isMasked: Bool { widgetRenderingMode != .fullColor }

    var body: some View {
        let path = Self.glyphPath(text, font: font)
        let size = path.boundingRect.size
        let bw = Artist.shared.poiTextBorderWidth*1.5
        ZStack(alignment: .topLeading) {
            // Casing first (behind), rounded so corners don't spike.
            if !isMasked {
                path.stroke(style: StrokeStyle(lineWidth: bw,
                                               lineCap: .round, lineJoin: .round))
                    .foregroundStyle(stroke)
                    .shadow(color: .black.opacity(0.35), radius: 2.5, y: 0.5)
            }
            path.fill(fill)
        }
        // Size to the ink box; pad for the half of the stroke that sits
        // outside it, so layout (and the trailing offset) account for it.
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .padding(lineWidth / 2)
    }

    // MARK: Glyph path (cached)

    @MainActor private static var cache: [String: Path] = [:]

    static func glyphPath(_ string: String, font: UIFont) -> Path {
        let key = "\(string)|\(font.pointSize)"
        if let cached = cache[key] { return cached }

        let attr = NSAttributedString(string: string, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attr)
        let runs = CTLineGetGlyphRuns(line) as! [CTRun]
        let cg   = CGMutablePath()

        for run in runs {
            let attrs = CTRunGetAttributes(run) as NSDictionary
            guard let ctFont = attrs[kCTFontAttributeName as String] else { continue }
            let f = ctFont as! CTFont
            for i in 0 ..< CTRunGetGlyphCount(run) {
                let range = CFRangeMake(i, 1)
                var glyph = CGGlyph(); CTRunGetGlyphs(run, range, &glyph)
                var pos   = CGPoint();  CTRunGetPositions(run, range, &pos)
                if let gp = CTFontCreatePathForGlyph(f, glyph, nil) {
                    cg.addPath(gp, transform: CGAffineTransform(translationX: pos.x, y: pos.y))
                }
            }
        }

        // CoreText is y-up; flip to SwiftUI's y-down and normalise to (0,0).
        let bb = cg.boundingBoxOfPath
        guard !bb.isNull else { return Path() }
        var flip = CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: -bb.minX, y: -bb.maxY)
        let path = Path(cg.copy(using: &flip) ?? cg)
        cache[key] = path
        return path
    }
}

#Preview {
    ZStack {
        Color.black
        POILabelView(category: .sun,
                     text:     "Sun")
    }
    .ignoresSafeArea()
}

