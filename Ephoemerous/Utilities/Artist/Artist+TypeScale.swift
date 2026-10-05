import SwiftUI
import UIKit

// MARK: - Type scale
// Every mark on the sky follows the system Text Size. SwiftUI `Text`
// already does — `.font(.footnote)` resolves against the environment — but
// three things don't:
//
//   • the CoreText names (`OutlinedText`), which need a concrete `UIFont`,
//   • the badges, sized in points,
//   • the layout maths (spacing, collision boxes) built on those points.
//
// They all go through here, keyed by the environment's `DynamicTypeSize`,
// so the whole label system grows as one. Read the size from the view's
// environment, never from `UIApplication`: a cached font freezes the size
// at launch and ignores a change made while the app is open.
extension Artist {

    /// The largest size the SKY draws at. Past this, names and badges pile
    /// into each other and the sky turns into a wall of text — the chrome
    /// and sheets keep scaling all the way. ▼ TWEAK the ceiling here ▼
    var skyTypeCeiling: DynamicTypeSize { .accessibility3 }

    /// How much bigger than the default (Large) size a mark draws at.
    /// 1 at the default; footnote's curve, the label system's body voice.
    @MainActor
    func typeScale(_ size: DynamicTypeSize) -> CGFloat {
        TypeScaleCache.scale(size)
    }

    /// A text style as a concrete `UIFont` at `size` — bold, in `design`.
    /// The CoreText voice of the POI names.
    @MainActor
    func labelFont(_ style:  UIFont.TextStyle,
                   design:   UIFontDescriptor.SystemDesign = .serif,
                   size:     DynamicTypeSize) -> UIFont {
        TypeScaleCache.font(style, design: design, size: size)
    }
}

// MARK: - Cache
// Labels ask for their font every pinch frame; building a UIFont through
// the descriptor chain each time would be the cost. One lookup per combo.
@MainActor
private enum TypeScaleCache {

    private static var fonts:  [String: UIFont]           = [:]
    private static var scales: [DynamicTypeSize: CGFloat] = [:]

    static func font(_ style: UIFont.TextStyle,
                     design:  UIFontDescriptor.SystemDesign,
                     size:    DynamicTypeSize) -> UIFont {
        let key = "\(style.rawValue)|\(design.rawValue)|\(size)"
        if let cached = fonts[key] { return cached }
        let base = preferred(style, size: size)
        var desc = base.fontDescriptor
        desc     = desc.withDesign(design) ?? desc
        desc     = desc.withSymbolicTraits(.traitBold) ?? desc
        let font = UIFont(descriptor: desc, size: base.pointSize)
        fonts[key] = font
        return font
    }

    static func scale(_ size: DynamicTypeSize) -> CGFloat {
        if let cached = scales[size] { return cached }
        let s = preferred(.footnote, size: size).pointSize
              / preferred(.footnote, size: .large).pointSize
        scales[size] = s
        return s
    }

    /// The system font for a style at an explicit size. watchOS has no
    /// trait collections — it reads the wearer's own setting instead.
    private static func preferred(_ style: UIFont.TextStyle, size: DynamicTypeSize) -> UIFont {
        #if os(watchOS)
        UIFont.preferredFont(forTextStyle: style)
        #else
        UIFont.preferredFont(forTextStyle:   style,
                             compatibleWith: UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size)))
        #endif
    }
}
