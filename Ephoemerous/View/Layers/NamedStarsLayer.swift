import SwiftUI
import simd
import LoreKit

// MARK: - NamedStarsLayer
// Proper-named stars surfaced as Apple-Maps-style POIs at high zoom.
// Mirrors ConstellationNamesLayer in shape:
//   - one-time filter to the proper-name subset (~300 stars, not 10k)
//   - per-frame projection + screen-cull
//   - draw via `drawPOILabel(category: .namedStar(...))` so the tier
//     engine handles dot → badge → text reveal as the user zooms
//   - publishes hit-rects to `state.namedStarHitRects` once the badge
//     itself is visible, so `ObjectsTrackingOverlay` can drop tap
//     targets that hand off to `state.focus(on: .star(...))`
//
// The layer self-gates on `scale >= artist.namedStarDotIn` so nothing
// renders below that threshold — by design, named-star dots start a
// touch *after* constellation labels finish revealing their text, so
// the canvas reveals information in waves instead of all at once.
struct NamedStarsLayer: EGridLayer {
    /// Proper-name subset, computed once at first access. Iterating
    /// the full 10k-star database every frame would be wasteful — this
    /// filter is the entire reason the layer is cheap.
    ///
    /// Deduped by `name`: the BSC has multiple rows sharing a Bayer
    /// designation (binary-star components — α Cen A / B, etc.), and
    /// drawing two pentagon badges on top of each other would just
    /// stack identical labels. First encountered wins.
    private static let candidates: [EStar] = {
        var seen = Set<String>()
        var out:  [EStar] = []
        for star in StarDatabase.shared.workableStars where star.properName != nil {
            if seen.insert(star.name).inserted { out.append(star) }
        }
        return out
    }()

    /// Reverse lookup for the tap overlay — published hit-rects key
    /// by `star.name` (the catalogue name), and the overlay needs the
    /// EStar back to call `state.focus(on: .star(star))`. Built from
    /// the already-deduped `candidates`, so no collision concerns —
    /// but use a non-trapping initializer anyway so a future data
    /// quirk can't crash app launch.
    private static let candidatesByName: [String: EStar] = Dictionary(
        candidates.map { ($0.name, $0) },
        uniquingKeysWith: { first, _ in first }
    )

    /// O(1) membership test used by `StarsLayer` to skip stars that
    /// this layer is about to redraw on top. Without this, ~300
    /// proper-named stars get a full `rotate + scale + fill` of their
    /// star path *and* a dot/badge from `NamedStarsLayer` at every
    /// frame above `namedStarDotIn` — the underlying star is then
    /// hidden beneath the badge but still painted.
    static let candidateNames: Set<String> = Set(candidates.map(\.name))

    /// Resolve a star from a published hit-rect key.
    static func star(named name: String) -> EStar? {
        candidatesByName[name]
    }

    /// Extract the `EStar.id` UUID from an `ESkyObject` id of the form
    /// `"star_<uuid>"`, or `nil` for non-star / nil ids. Lets the draw
    /// loop match the promoted star by raw UUID (no per-star string
    /// allocation). Parsed once per frame, not per star.
    static func starUUID(from objectID: String?) -> UUID? {
        guard let objectID, objectID.hasPrefix("star_") else { return nil }
        return UUID(uuidString: String(objectID.dropFirst("star_".count)))
    }

    func draw(in dc: inout EGraphicContext) {
        let stateRef = dc.state
        let scale    = dc.renderedScale

        // Promoted star UUIDs, parsed ONCE per frame from the selection ids
        // ("star_<uuid>"). Needed before the gate below so a star selected
        // at low zoom still promotes.
        let selStarUUID   = Self.starUUID(from: dc.selectedObjectID)
        let deselStarUUID = Self.starUUID(from: dc.deselectingID)

        // Below the dot threshold the layer normally doesn't run — but we
        // pan to a selected object WITHOUT zooming, so a star tapped/searched
        // at low zoom must still show its promoted pin. Draw just the
        // promoted star(s) here, clear stale hit-rects, and bail.
        guard scale >= artist.namedStarDotIn else {
            drawPromotedBelowGate(selected: selStarUUID, deselecting: deselStarUUID, in: &dc)
            if !stateRef.namedStarHitRects.isEmpty {
                DispatchQueue.main.async { stateRef.namedStarHitRects = [:] }
            }
            return
        }

        // FavouritesLayer draws favourited stars with their own badge
        // + earlier thresholds — skip them here so
        // there's no double-render.
        let favouriteNames = Set(dc.state.favouriteStars.map(\.name))
        let tappable      = scale >= artist.namedStarTapMinScale

        // Badge size is constant within `.namedStar` — probe once.
        guard let probe = Self.candidates.first else { return }
        let badgeSize = artist.poiStyle(for: .namedStar(probe)).badgeSize

        var rects: [String: CGRect] = [:]
        if tappable { rects.reserveCapacity(Self.candidates.count) }

        // Same zoom-driven magnitude cap StarsLayer uses (frozen at the
        // pan destination during a transition) so named-star badges
        // appear in step with the star dots and don't densify mid-pan.
        let magCap = dc.state.magnitudeCap(forScale: dc.state.magnitudeScale)
        for star in Self.candidates where !favouriteNames.contains(star.name) {
            guard star.magnitude <= magCap else { continue }

            let (pRA, pDec) = EPrecession.precess(ra: star.rightAscension, dec: star.declination,
                                                  to: dc.renderedObservationDate)
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.localSiderealOffset)
            guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint) else { continue }
            let sc = dc.toScreen(proj)

            // Off-screen cull — no point drawing (or registering a
            // tap target for) something the user can't see.
            guard artist.starPointFallsWithinMarigin(sc, in: dc) else { continue }

            // Cheap UUID compare for the 298 non-promoted stars; only
            // the selected / deselecting star builds the id string +
            // reads its spring.
            let promo: Double = (star.id == selStarUUID || star.id == deselStarUUID)
                ? dc.poiPromotion(forObjectID: ESkyObject.star(star).id)
                : 0
            artist.drawPOILabel(
                at:        sc,
                glyph:     .symbol(.starFill),
                text:      star.displayName,
                category:  .namedStar(star),
                drawDot:   true,
                promotion: promo,
                in:        &dc
            )

            guard tappable else { continue }
            let hit: CGFloat = max(44, badgeSize + 16)
            rects[star.name] = CGRect(x: sc.x - hit / 2, y: sc.y - hit / 2,
                                      width: hit, height: hit)
        }

        let snapshot = rects
        // Equality-guard — at 120 Hz we'd otherwise republish the
        // same ~hundred-entry dict every frame and re-invalidate
        // ObjectsTrackingOverlay for no reason.
        DispatchQueue.main.async {
            if stateRef.namedStarHitRects != snapshot {
                stateRef.namedStarHitRects = snapshot
            }
        }
    }

    /// Draw ONLY the promoted (selected / deselecting) named star(s), used
    /// below `namedStarDotIn` where the main loop doesn't run. Keeps a star
    /// selected from search/tap at low zoom showing its promoted pin (we
    /// pan to it but never zoom). No dot, no hit-rects — just the pin; it
    /// fades out on its own as `promo` returns to 0 (drawPOILabel bails when
    /// reveal hits 0).
    private func drawPromotedBelowGate(selected: UUID?,
                                       deselecting: UUID?,
                                       in dc: inout EGraphicContext) {
        let ids = [selected, deselecting].compactMap { $0 }
        guard !ids.isEmpty else { return }

        for star in Self.candidates where ids.contains(star.id) {
            let (pRA, pDec) = EPrecession.precess(ra: star.rightAscension, dec: star.declination,
                                                  to: dc.renderedObservationDate)
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.localSiderealOffset)
            guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint) else { continue }
            let sc = dc.toScreen(proj)

            let promo = dc.poiPromotion(forObjectID: ESkyObject.star(star).id)
            artist.drawPOILabel(
                at:        sc,
                glyph:     .symbol(.starFill),
                text:      star.displayName,
                category:  .namedStar(star),
                drawDot:   false,
                promotion: promo,
                in:        &dc
            )
        }
    }
}
