import SwiftUI
import UIKit
import CoreText
import LoreKit

// MARK: - POILabelView
// Apple-Maps-style POI label as a STANDALONE, reusable SwiftUI view — the
// native counterpart of the Canvas `drawPOILabel`. Driven by a
// `POICategory`, so every tracked body (sun / moon / planets / stars /
// constellations) gets the same component, faithful to the production
// palette via `EArtist.poiStyle(for:)`.
//
// Layout anchor is the BADGE: the name floats to its right as a
// non-layout overlay, so the view's size == the badge and a caller can
// `.position(...)` it precisely on the sky point. Circle badge for now
// (squircles come later).
//
// Pieces, bottom → top, mirroring the Canvas treatment:
//   • radial gradient fill — bright `gradientTop` centre → deep
//     `gradientBottom` rim (a little glowing orb)
//   • casing ring in `border` (the light outline that reads against a
//     busy sky) + a soft drop shadow for lift
//   • the symbol glyph
//   • the name, cased (8-way outline) in the gradient's OUTER colour
struct POILabelView: View {
    
    let category: POICategory
    let glyph:    POIGlyph
    let text:     String
    var showsName: Bool = true
    
    /// Gap (pt) between the badge's trailing edge and the name.
    private let nameGap: CGFloat = 6
    
    private var style: EArtist.POICategoryStyle { EArtist.shared.poiStyle(for: category) }
    
    var body: some View {
        badge
            .overlay(alignment: .leading) {
                VStack {
                    if showsName {
                        // Real glyph-outline casing (see `OutlinedText`); fill
                        // in the gradient's OUTER colour, same as the Canvas
                        // flat label.
                        OutlinedText(text:      text,
                                     fill:      style.gradientTop,
                                     stroke:    style.border,
                                     lineWidth: 2.5,
                                     font:      Self.nameFont)
                        // Overlay aligns the name's leading to the badge's
                        // leading; push it right past the badge so the text
                        // trails the symbol and never overlaps it.
                        .offset(x: style.badgeSize + nameGap)
                    }
                }
                
            }
    }

    /// Footnote serif bold, as a `UIFont` (CoreText needs a concrete font
    /// to lay out glyph paths). `preferredFont` keeps Dynamic Type.
    private static let nameFont: UIFont = {
        let base = UIFont.preferredFont(forTextStyle: .footnote)
        var desc = base.fontDescriptor
        desc = desc.withDesign(.serif) ?? desc
        desc = desc.withSymbolicTraits(.traitBold) ?? desc
        return UIFont(descriptor: desc, size: base.pointSize)
    }()
    
    // MARK: Badge
    
    private var badge: some View {
        let d  = style.badgeSize
        let bw = EArtist.shared.poiTextBorderWidth
        return ZStack {
            Circle()
                .fill(
                    
                    LinearGradient(colors: [
                        style.gradientTop,
                        style.gradientBottom
                    ], startPoint: .bottom, endPoint: .top)
                    /*
                     RadialGradient(
                     colors:      [style.gradientTop, style.gradientBottom],
                     center:      .center,
                     startRadius: 0,
                     endRadius:   d / 2
                     )
                     */
                )
//            glyphView
        }
//        .glassEffect()
        .frame(width: d, height: d)
        // Casing ring — the light outline doing the legibility work.
        .overlay(Circle().stroke(style.border, lineWidth: bw)
            .glassEffect(.clear.interactive()))
        // Soft drop shadow for lift (one view → cheap, unlike the Canvas
        // per-glyph blur).
        .shadow(color: .black.opacity(0.35), radius: 2.5, y: 0.5)
    }
    
    @ViewBuilder
    private var glyphView: some View {
        Group {
            switch glyph {
            case .sfSymbol(let name): Image(systemName: name)
            case .unicode(let str):   Text(str)
            }
        }
        .font(.system(size: style.symbolPointSize, weight: .semibold))
        .foregroundStyle(style.symbolColor)
    }
}

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

    var body: some View {
        let path = Self.glyphPath(text, font: font)
        let size = path.boundingRect.size
        let bw = EArtist.shared.poiTextBorderWidth*1.5
        ZStack(alignment: .topLeading) {
            // Casing first (behind), rounded so corners don't spike.
            path.stroke(style: StrokeStyle(lineWidth: bw,
                                           lineCap: .round, lineJoin: .round))
                .foregroundStyle(stroke)
                .shadow(color: .black.opacity(0.35), radius: 2.5, y: 0.5)
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
                     glyph:    .sfSymbol("sun.max.fill"),
                     text:     "Sun")
    }
    .ignoresSafeArea()
}

