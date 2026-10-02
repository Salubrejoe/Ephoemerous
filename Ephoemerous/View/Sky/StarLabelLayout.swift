import SwiftUI
import UIKit

// MARK: - StarLabelLayout
// Star labels never overlap — the Maps way: labels are placed in priority
// order, and one that would land on something already placed gives way.
//
//   1. Fixed, never yield: the selected object's pin; the Sun, the Moon,
//      the planets and the spacecraft (their own layer already declutters
//      them among themselves).
//   2. Favourite stars, brightest first. Their BADGE always stays (a
//      favourite has no dot to fall back to); only the name can give way.
//   3. Named stars, brightest first. A name that would overlap drops; a
//      BADGE that would overlap falls back to the star's tier-0 pentagon,
//      so the star never vanishes — it just stops shouting.
//
// Everything is compared where it lands ON SCREEN (`LabelComfortZone
// .screenPoint`), because labels are drawn upright at constant size there
// whatever the live pinch and rotation. Name widths are measured with the
// label's own font. One pass per frame; the layers just read the result.
struct StarLabelLayout {

    /// Named stars drawn as their pentagon dot instead of a badge.
    let dotOnly:     Set<String>
    /// Stars whose badge shows but whose name gives way.
    let hiddenNames: Set<String>

    static let none = StarLabelLayout(dotOnly: [], hiddenNames: [])

    private init(dotOnly: Set<String>, hiddenNames: Set<String>) {
        self.dotOnly     = dotOnly
        self.hiddenNames = hiddenNames
    }

    @MainActor
    init(camera: SkyCamera, scale: CGFloat, comfort: LabelComfortZone, date: Date,
         favourites: [Star], named: [Star], selection: SkyObject?) {
        let a = Artist.shared
        var placed: [CGRect] = []
        var dots   = Set<String>()
        var names  = Set<String>()

        func collides(_ r: CGRect) -> Bool { placed.contains { $0.intersects(r) } }

        // 1 · Fixed marks.
        if let selection, let sc = SkyLabObjects.screen(selection, camera: camera, date: date) {
            placed.append(contentsOf: Self.pinFootprint(selection, at: comfort.screenPoint(sc), date: date))
        }
        let bodies: [SkyObject] = [.sun, .moon] + Planet.all.map { .planet($0) } + Spacecraft.allCases.map { .spacecraft($0) }
        for body in bodies where body != selection {
            guard let category = SkyLabObjects.poiMark(body, date: date)?.category,
                  let sc       = SkyLabObjects.screen(body, camera: camera, date: date)
            else { continue }
            let style = a.poiStyle(for: category)
            guard scale >= style.badgeIn else { continue }
            let p = comfort.screenPoint(sc)
            placed.append(Self.badgeRect(at: p, size: style.badgeSize))
            if scale >= style.textIn, comfort.nameVisibility(at: sc) > 0.01, let name = SkyLabObjects.poiMark(body, date: date)?.name {
                placed.append(Self.nameRect(name, at: p, badge: style.badgeSize))
            }
        }

        // 2 · Favourites, then 3 · named stars — brightest first in each.
        let queue: [(Star, POICategory, Bool)] =
              favourites.sorted { $0.magnitude < $1.magnitude }.map { ($0, .followedStar($0), true) }
            + named.sorted { $0.magnitude < $1.magnitude }.map { ($0, .namedStar($0), false) }
        for (star, category, isFavourite) in queue {
            if case .star(let s) = selection, s.id == star.id { continue }      // the pin has it
            let style = a.poiStyle(for: category)
            guard scale >= style.badgeIn,
                  let sc = camera.screen(equatorial: star.equatorialVector)
            else { continue }
            let p     = comfort.screenPoint(sc)
            let badge = Self.badgeRect(at: p, size: style.badgeSize)
            if collides(badge) && !isFavourite {
                dots.insert(star.id)
                continue
            }
            placed.append(badge)
            let speaks = scale >= style.textIn && comfort.nameVisibility(at: sc) > 0.01
            guard speaks else { continue }
            let name = Self.nameRect(star.displayName, at: p, badge: style.badgeSize)
            if collides(name) {
                names.insert(star.id)
            } else {
                placed.append(name)
            }
        }

        dotOnly     = dots
        hiddenNames = names
    }

    // MARK: Footprints (screen space)

    /// Breathing room around every mark, so labels don't kiss.
    private static let padding: CGFloat = 2

    private static func badgeRect(at p: CGPoint, size: CGFloat) -> CGRect {
        let d = size + Artist.shared.poiTextBorderWidth * 2
        return CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d).insetBy(dx: -padding, dy: -padding)
    }

    /// The name trails the badge: leading edge a gap past the badge, centred
    /// on its row — exactly where `POILabelView` draws it.
    private static func nameRect(_ text: String, at p: CGPoint, badge: CGFloat) -> CGRect {
        let w = textWidth(text)
        let h = nameFont.lineHeight
        return CGRect(x: p.x + badge / 2 + 6, y: p.y - h / 2, width: w, height: h)
            .insetBy(dx: -padding, dy: -padding)
    }

    /// The promoted pin: its lifted, enlarged badge and the name hung under
    /// the precise dot.
    @MainActor
    private static func pinFootprint(_ object: SkyObject, at p: CGPoint, date: Date) -> [CGRect] {
        let a = Artist.shared
        guard let mark = SkyLabObjects.poiMark(object, date: date) else {
            // A selected constellation is emphasised in place, not pinned.
            return []
        }
        let style = a.poiStyle(for: mark.category)
        let d     = style.badgeSize * a.poiSelectScale * (a.poiHasRings(mark.category) ? a.saturnRingOuter.width : 1)
        let lift  = a.poiSelectLiftFactor * style.badgeSize
        let badge = CGRect(x: p.x - d / 2, y: p.y - lift - d / 2, width: d, height: d)
        let w     = textWidth(mark.name, font: pinFont)
        let name  = CGRect(x: p.x - w / 2, y: p.y + a.poiSelectNameDrop, width: w, height: pinFont.lineHeight)
        return [badge.insetBy(dx: -padding, dy: -padding), name.insetBy(dx: -padding, dy: -padding)]
    }

    // MARK: Text metrics

    /// The flat label's name font (footnote serif bold) — see `POILabelView`.
    private static let nameFont: UIFont = font(.footnote)
    /// The promoted pin's name font (title 2 serif bold) — see `PromotedLabel`.
    private static let pinFont:  UIFont = font(.title2)

    private static func font(_ style: UIFont.TextStyle) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        var desc = base.fontDescriptor
        desc = desc.withDesign(.serif) ?? desc
        desc = desc.withSymbolicTraits(.traitBold) ?? desc
        return UIFont(descriptor: desc, size: base.pointSize)
    }

    @MainActor private static var widthCache: [String: CGFloat] = [:]

    /// Measured width plus the outline casing either side; cached per name.
    @MainActor
    private static func textWidth(_ text: String, font: UIFont = nameFont) -> CGFloat {
        let key = "\(font.pointSize)|\(text)"
        if let w = widthCache[key] { return w }
        let w = ceil((text as NSString).size(withAttributes: [.font: font]).width) + 3
        widthCache[key] = w
        return w
    }
}
